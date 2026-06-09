import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review_model.dart';

final reviewsProvider = StreamProvider.family<List<ReviewModel>, String>((ref, serviceName) {
  final name = serviceName.trim();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  if (name.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('reviews')
      .where('serviceName', isEqualTo: name)
      .snapshots()
      .map((snapshot) {
        final reviews = snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .where((review) {
            // Show review if it's NOT disabled
            // OR if it IS disabled but belongs to the current user
            return !review.isDisabled || review.userId == currentUserId;
          })
          .toList();
        
        reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return reviews;
      });
});
