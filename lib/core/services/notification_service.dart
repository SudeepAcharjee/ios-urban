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
    databaseURL:
        'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Initialize Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          // Handle notification tap
        },
      );

      // Create Notification Channels for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      const AndroidNotificationChannel
      workAssignedChannel = AndroidNotificationChannel(
        'work_assigned_channel',
        'Work Assigned Notifications',
        description:
            'This channel is used for work assignment notifications with custom ringtone.',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('call_ringtone'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(workAssignedChannel);

      // Foreground FCM listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showLocalNotification(
            message.notification!.title ?? 'New Notification',
            message.notification!.body ?? '',
            type: message.data['type']?.toString(),
          );
        }
      });

      // Print FCM token for debugging
      getToken().then((token) {
        print("FCM Token: $token");
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
      _userSub = _database.ref('notifications/${user.uid}').onChildAdded.listen((
        event,
      ) {
        final data = event.snapshot.value as Map?;
        if (data != null) {
          final timestamp = data['createdAt'] ?? data['timestamp'];

          // CRITICAL: Only show if the notification was created AFTER the listener started
          if (timestamp != null && (timestamp as int) > listenerStartTime) {
            _showLocalNotification(
              data['title'] ?? 'Urban Services',
              data['message'] ?? data['body'] ?? '',
              type: data['type']?.toString(),
            );
          }
        }
      });
    }
  }

  static Future<void> _showLocalNotification(
    String title,
    String body, {
    String? type,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;

    final bool isWorkAssigned = type == 'worker_assigned' || type == 'new_task';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          isWorkAssigned ? 'work_assigned_channel' : 'high_importance_channel',
          isWorkAssigned
              ? 'Work Assigned Notifications'
              : 'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          sound: isWorkAssigned
              ? const RawResourceAndroidNotificationSound('call_ringtone')
              : null,
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: isWorkAssigned ? 'call_ringtone.wav' : null,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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

  static Future<void> notifyAdminsAboutPendingVerification({
    required String bookingId,
    required String bookingTitle,
    required String workerId,
    required String workerName,
  }) async {
    try {
      final adminsSnapshot = await _database.ref('admins').get();
      if (!adminsSnapshot.exists) return;

      final dynamic data = adminsSnapshot.value;
      List<String> adminIds = [];
      if (data is Map) {
        data.forEach((key, value) {
          if (value == true || (value is Map && value['active'] == true)) {
            adminIds.add(key.toString());
          } else if (value != null) {
            adminIds.add(key.toString());
          }
        });
      }

      if (adminIds.isEmpty) return;

      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String messageText =
          'Booking "$bookingTitle" (ID: #${bookingId.toUpperCase()}) completed by $workerName is pending verification.';

      for (final adminId in adminIds) {
        final notificationRef = _database.ref('notifications/$adminId').push();
        await notificationRef.set({
          'title': 'Booking Pending Verification',
          'message': messageText,
          'body': messageText,
          'timestamp': timestamp,
          'createdAt': timestamp,
          'type': 'booking_verification',
          'isRead': false,
          'bookingId': bookingId,
          'senderId': workerId,
        });
      }
    } catch (e) {
      print('Error notifying admins: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final title =
      message.notification?.title ?? data['title'] ?? 'Urban Services';
  final body =
      message.notification?.body ?? data['message'] ?? data['body'] ?? '';

  if (title.isNotEmpty || body.isNotEmpty) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await localNotifications.initialize(settings: initSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const AndroidNotificationChannel
    workAssignedChannel = AndroidNotificationChannel(
      'work_assigned_channel',
      'Work Assigned Notifications',
      description:
          'This channel is used for work assignment notifications with custom ringtone.',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('call_ringtone'),
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(workAssignedChannel);

    final String? type = data['type']?.toString();
    final bool isWorkAssigned = type == 'worker_assigned' || type == 'new_task';

    final int notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          isWorkAssigned ? 'work_assigned_channel' : 'high_importance_channel',
          isWorkAssigned
              ? 'Work Assigned Notifications'
              : 'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          sound: isWorkAssigned
              ? const RawResourceAndroidNotificationSound('call_ringtone')
              : null,
        );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: isWorkAssigned ? 'call_ringtone.wav' : null,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
