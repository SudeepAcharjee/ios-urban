import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

final allNotificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null) {
    return Stream.value([]);
  }

  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  return database.ref('notifications/${user.uid}').onValue.map((event) {
    final List<NotificationModel> notifications = [];
    final data = event.snapshot.value as Map?;
    
    if (data != null) {
      data.forEach((key, value) {
        if (value is Map) {
          notifications.add(NotificationModel.fromMap(key.toString(), value));
        }
      });
    }
    
    notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }).handleError((error) {
    print('Notification Stream Error: $error');
    return <NotificationModel>[];
  });
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(allNotificationsProvider).value ?? [];
  return notifications.where((n) => !n.isRead).length;
});

final notificationActionsProvider = Provider((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  return NotificationActions(user?.uid);
});

class NotificationActions {
  final String? userId;
  NotificationActions(this.userId);

  Future<void> clearAll() async {
    if (userId == null) return;
    
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );

    final snapshot = await database.ref('notifications/$userId').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      if (data != null) {
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          updates[key] = null;
        });
        await database.ref('notifications/$userId').update(updates);
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (userId == null) return;
    
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );

    await database.ref('notifications/$userId/$notificationId').update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    if (userId == null) return;
    
    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );

    final snapshot = await database.ref('notifications/$userId').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      if (data != null) {
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          updates['$key/isRead'] = true;
        });
        await database.ref('notifications/$userId').update(updates);
      }
    }
  }
}
