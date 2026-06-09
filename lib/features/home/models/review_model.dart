import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String userName;
  final String userAvatar;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final String serviceId;
  final String userId;
  final bool isDisabled;

  ReviewModel({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.comment,
    required this.timestamp,
    required this.serviceId,
    required this.userId,
    this.isDisabled = false,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      userName: data['userName'] ?? 'Anonymous',
      userAvatar: data['userProfilePic'] ?? data['userAvatar'] ?? '',
      rating: (data['serviceRating'] ?? data['rating'] ?? 5.0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['createdAt'] as Timestamp?)?.toDate() ?? (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      serviceId: data['serviceId'] ?? '',
      userId: data['userId'] ?? data['user'] ?? '',
      isDisabled: data['isDisabled'] ?? false,
    );
  }
}
