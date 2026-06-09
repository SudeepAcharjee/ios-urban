import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
          // Handle notification tap
        },
      );

      // Create Notification Channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Foreground FCM listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(
            message.notification!.title ?? 'New Notification',
            message.notification!.body ?? '',
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
            _showLocalNotification(
              data['title'] ?? 'Urban Services', 
              data['message'] ?? data['body'] ?? '',
            );
          }
        }
      });
    }
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    
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
