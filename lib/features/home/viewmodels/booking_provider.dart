import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

DateTime _parseReviewDate(dynamic val1, dynamic val2) {
  for (final val in [val1, val2]) {
    if (val is Timestamp) return val.toDate();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    if (val is String) {
      final d = DateTime.tryParse(val);
      if (d != null) return d;
    }
  }
  return DateTime(1970);
}

final userBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
        final docs = snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList();
        docs.sort((a, b) {
          final aDate = _parseReviewDate(a['createdAt'], a['timestamp']);
          final bDate = _parseReviewDate(b['createdAt'], b['timestamp']);
          return bDate.compareTo(aDate);
        });
        return docs;
      });
});

final userReviewsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('reviews')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['userId'] == user.uid || data['user'] == user.uid;
            })
            .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
            .toList();

        list.sort((a, b) {
          final aDate = _parseReviewDate(a['createdAt'], a['timestamp']);
          final bDate = _parseReviewDate(b['createdAt'], b['timestamp']);
          return bDate.compareTo(aDate);
        });
        return list;
      });
});

final shopReviewsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('reviews')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .where((doc) {
              final data = doc.data();
              final sId = data['shopId'] ?? data['ownerId'] ?? data['vendorId'];
              return sId == user.uid;
            })
            .map((doc) => {
              ...doc.data(),
              'id': doc.id,
            })
            .toList();

        list.sort((a, b) {
          final aDate = _parseReviewDate(a['createdAt'], a['timestamp']);
          final bDate = _parseReviewDate(b['createdAt'], b['timestamp']);
          return bDate.compareTo(aDate);
        });
        return list;
      });
});
