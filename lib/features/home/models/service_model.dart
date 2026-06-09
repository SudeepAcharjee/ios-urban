import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String image;
  final String category;
  final String categoryId;
  final String price;
  final String oldPrice;
  final String shortDescription;
  final String longDescription;
  final String status;
  final List<String> whatsIncluded;
  final List<String> whatsNotIncluded;
  final List<String> gallery;
  final String serviceTime;
  final double rating; // Default fallback
  final int reviews;   // Default fallback
  final double? latitude;
  final double? longitude;
  final double? radius;

  ServiceModel({
    required this.id,
    required this.name,
    required this.image,
    required this.category,
    required this.categoryId,
    required this.price,
    required this.oldPrice,
    required this.shortDescription,
    required this.longDescription,
    required this.status,
    required this.whatsIncluded,
    required this.whatsNotIncluded,
    this.gallery = const [],
    this.serviceTime = '60 mins',
    this.rating = 4.8,
    this.reviews = 120,
    this.latitude,
    this.longitude,
    this.radius,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      name: data['name'] ?? '',
      image: data['image'] ?? '',
      category: data['category'] ?? '',
      categoryId: data['categoryId'] ?? '',
      price: data['price']?.toString() ?? '0',
      oldPrice: data['oldPrice']?.toString() ?? '',
      shortDescription: data['shortDescription'] ?? '',
      longDescription: data['longDescription'] ?? '',
      status: data['status'] ?? 'Active',
      whatsIncluded: List<String>.from(data['whatsIncluded'] ?? []),
      whatsNotIncluded: List<String>.from(data['whatsNotIncluded'] ?? []),
      gallery: List<String>.from(data['gallery'] ?? []),
      serviceTime: data['serviceTime'] ?? '60 mins',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
      reviews: data['reviews'] as int? ?? 120,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      radius: (data['radius'] as num?)?.toDouble(),
    );
  }
}
