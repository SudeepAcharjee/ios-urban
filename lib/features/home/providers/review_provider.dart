import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review_model.dart';

final reviewsProvider = StreamProvider.family<List<ReviewModel>, String>((ref, serviceName) {
  final target = serviceName.trim().toLowerCase();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  if (target.isEmpty) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('reviews')
      .snapshots()
      .map((snapshot) {
        final List<ReviewModel> reviews = [];

        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();
            final sName = (data['serviceName'] ?? data['title'] ?? data['serviceTitle'] ?? '').toString().trim().toLowerCase();
            final sId = (data['serviceId'] ?? '').toString().trim().toLowerCase();

            // Match if serviceName or serviceId equals target
            final matches = sName == target || sId == target || (sName.isNotEmpty && (sName.contains(target) || target.contains(sName)));
            if (!matches) continue;

            final review = ReviewModel.fromFirestore(doc);
            if (!review.isDisabled || review.userId == currentUserId) {
              reviews.add(review);
            }
          } catch (_) {
            // Ignore corrupted individual review doc and continue parsing others
          }
        }

        reviews.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return reviews;
      });
});
