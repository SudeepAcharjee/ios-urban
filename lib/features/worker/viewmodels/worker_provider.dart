import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

final workerReviewsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('reviews')
      .where('workerId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList());
});

final workerAssignedTasksProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('bookings')
      .where('workerId', isEqualTo: user.uid)
      .where('status', whereIn: ['Confirmed', 'In Progress', 'Assigned', 'Pending Verification'])
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

final workerAllTasksProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('bookings')
      .where('workerId', isEqualTo: user.uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

final workerCompletedTasksProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('bookings')
      .where('workerId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'Completed')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
});

final workerNotificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  // IMPORTANT: Use the same database URL as defined in NotificationService
  final database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref('notifications/${user.uid}');
  
  return database.onValue.map((event) {
    final snapshot = event.snapshot;
    if (snapshot.value == null) {
      return <Map<String, dynamic>>[];
    }

    final dynamic rawData = snapshot.value;
    final List<Map<String, dynamic>> notifications = [];

    if (rawData is Map) {
      rawData.forEach((key, value) {
        if (value is Map) {
          try {
            notifications.add({
              'id': key.toString(),
              ...Map<String, dynamic>.from(value),
            });
          } catch (e) {
            print('Error parsing notification $key: $e');
          }
        }
      });
    }

    // Sort by timestamp descending (newest first)
    notifications.sort((a, b) {
      final aTime = a['timestamp'] ?? 0;
      final bTime = b['timestamp'] ?? 0;
      return bTime.toString().compareTo(aTime.toString()); // Handle potential string/int mix
    });

    return notifications;
  });
});

final workerNotificationActionsProvider = Provider((ref) {
  return WorkerNotificationActions();
});

final unreadWorkerNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(workerNotificationsProvider).value ?? [];
  return notifications.where((n) => !(n['isRead'] ?? (n['status'] == 'read'))).length;
});

class WorkerNotificationActions {
  void markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref('notifications/${user.uid}/$notificationId');

    await database.update({'isRead': true});
  }

  void clearAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    ).ref('notifications/${user.uid}');

    await database.remove();
  }

  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final database = FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
    );

    final snapshot = await database.ref('notifications/${user.uid}').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      if (data != null) {
        final Map<String, dynamic> updates = {};
        data.forEach((key, value) {
          updates['$key/isRead'] = true;
        });
        await database.ref('notifications/${user.uid}').update(updates);
      }
    }
  }
}
