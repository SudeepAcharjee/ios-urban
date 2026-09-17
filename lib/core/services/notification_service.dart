import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'sound_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  static StreamSubscription? _userSub;

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      return null;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      return false;
    }
  }

  static Future<void> initialize() async {
    try {
      // Initialize SoundService
      SoundService.initialize();

      // Initialize Local Notifications
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          SoundService.stopSound();
        },
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Create Standard High Importance Notification Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );
      await androidPlugin?.createNotificationChannel(channel);

      // Create Custom Sound Booking Alerts Channel for Android
      const AndroidNotificationChannel bookingChannel = AndroidNotificationChannel(
        'booking_alerts_channel',
        'Booking Notifications',
        description: 'This channel is used for urgent new booking and service alerts.',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('booking_alert'),
        playSound: true,
      );
      await androidPlugin?.createNotificationChannel(bookingChannel);

      // Foreground FCM listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          final title = message.notification!.title ?? 'New Notification';
          final body = message.notification!.body ?? '';
          final type = message.data['type']?.toString();
          final isBooking = _isBookingNotification(title, body, type);

          _showLocalNotification(
            title,
            body,
            isBooking: isBooking,
          );
        }
      });

      // Listen to Realtime Database
      _startRTDBListeners();
      
      // Listen for Auth changes to restart user-specific listeners
      FirebaseAuth.instance.authStateChanges().listen((user) {
        _startRTDBListeners();
      });

    } catch (e) {
      // Error handling
    }
  }

  static bool _isBookingNotification(String? title, String? message, String? type) {
    final t = (title ?? '').toLowerCase();
    final m = (message ?? '').toLowerCase();
    final typ = (type ?? '').toLowerCase();
    return typ.contains('booking') ||
        typ.contains('task') ||
        typ.contains('order') ||
        t.contains('booking') ||
        t.contains('task') ||
        t.contains('order') ||
        m.contains('booking') ||
        m.contains('booked') ||
        m.contains('requested');
  }

  static void _startRTDBListeners() {
    _userSub?.cancel();

    // Capture the exact time we started listening
    final int listenerStartTime = DateTime.now().millisecondsSinceEpoch;

    // Listen to Notifications node (notifications/{uid})
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userSub = _database.ref('notifications/${user.uid}').onChildAdded.listen((event) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          final timestamp = data['createdAt'] ?? data['timestamp'];
          
          // CRITICAL: Only show if the notification was created AFTER the listener started
          if (timestamp != null && (timestamp as int) > listenerStartTime) {
            final title = (data['title'] ?? 'Urban Services').toString();
            final message = (data['message'] ?? data['body'] ?? '').toString();
            final type = (data['type'] ?? '').toString();
            final isBooking = _isBookingNotification(title, message, type);

            _showLocalNotification(
              title, 
              message,
              isBooking: isBooking,
            );
          }
        }
      });
    }
  }

  static Future<void> _showLocalNotification(
    String title,
    String body, {
    bool isBooking = false,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isBooking ? 'booking_alerts_channel' : 'high_importance_channel',
      isBooking ? 'Booking Notifications' : 'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      sound: isBooking ? const RawResourceAndroidNotificationSound('booking_alert') : null,
      playSound: true,
    );
    
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: isBooking ? 'booking_alert.wav' : null,
      presentSound: true,
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Play urgent sound for new booking notifications
    if (isBooking) {
      SoundService.playBookingAlertSound();
    }
    
    await _localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> signOut() async {
    await _userSub?.cancel();
    _userSub = null;
  }
}
