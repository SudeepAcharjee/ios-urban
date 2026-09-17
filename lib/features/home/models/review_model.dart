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
    final data = doc.data() as Map<String, dynamic>? ?? {};

    double parseRating(dynamic val) {
      if (val == null) return 5.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 5.0;
    }

    DateTime parseDate(dynamic val1, dynamic val2) {
      for (final val in [val1, val2]) {
        if (val is Timestamp) return val.toDate();
        if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
        if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
        if (val is String) {
          final d = DateTime.tryParse(val);
          if (d != null) return d;
        }
      }
      return DateTime.now();
    }

    return ReviewModel(
      id: doc.id,
      userName: (data['userName'] ?? data['name'] ?? 'Anonymous').toString(),
      userAvatar: (data['userProfilePic'] ?? data['userAvatar'] ?? data['userImage'] ?? '').toString(),
      rating: parseRating(data['serviceRating'] ?? data['rating'] ?? data['technicianRating']),
      comment: (data['comment'] ?? data['review'] ?? '').toString(),
      timestamp: parseDate(data['createdAt'], data['timestamp']),
      serviceId: (data['serviceId'] ?? '').toString(),
      userId: (data['userId'] ?? data['user'] ?? '').toString(),
      isDisabled: data['isDisabled'] == true,
    );
  }
}
