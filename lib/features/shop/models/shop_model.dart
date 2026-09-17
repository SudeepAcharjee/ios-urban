import 'package:cloud_firestore/cloud_firestore.dart';

class ShopModel {
  final String uid;
  final String ownerName;
  final String shopName;
  final String email;
  final String phone;
  final String serviceType; // 'Car Servicing', 'Bike Servicing', 'Car & Bike Servicing'
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isOpen;
  final String status;
  final double rating;
  final String role;
  final DateTime? createdAt;

  final String? shopPhoto;
  final Map<String, dynamic> documents;
  final bool onboardingCompleted;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  const ShopModel({
    required this.uid,
    required this.ownerName,
    required this.shopName,
    required this.email,
    required this.phone,
    required this.serviceType,
    this.address = '',
    this.latitude,
    this.longitude,
    this.isOpen = true,
    this.status = 'pending',
    this.rating = 5.0,
    this.role = 'shop',
    this.createdAt,
    this.shopPhoto,
    this.documents = const {},
    this.onboardingCompleted = false,
    this.rejectionReason,
    this.submittedAt,
    this.approvedAt,
  });

  factory ShopModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ShopModel(
      uid: documentId,
      ownerName: map['ownerName'] ?? map['name'] ?? '',
      shopName: map['shopName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      serviceType: map['serviceType'] ?? 'Car & Bike Servicing',
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isOpen: map['isOpen'] ?? true,
      status: map['status'] ?? 'pending',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      role: map['role'] ?? 'shop',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      shopPhoto: map['shopPhoto'] as String?,
      documents: map['documents'] is Map
          ? Map<String, dynamic>.from(map['documents'])
          : {},
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      rejectionReason: map['rejectionReason'] as String?,
      submittedAt: map['submittedAt'] is Timestamp
          ? (map['submittedAt'] as Timestamp).toDate()
          : null,
      approvedAt: map['approvedAt'] is Timestamp
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'ownerName': ownerName,
      'name': ownerName,
      'shopName': shopName,
      'email': email,
      'phone': phone,
      'serviceType': serviceType,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'isOpen': isOpen,
      'status': status,
      'rating': rating,
      'role': role,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'shopPhoto': shopPhoto,
      'documents': documents,
      'onboardingCompleted': onboardingCompleted,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : null,
      'approvedAt': approvedAt != null
          ? Timestamp.fromDate(approvedAt!)
          : null,
    };
  }

  ShopModel copyWith({
    String? uid,
    String? ownerName,
    String? shopName,
    String? email,
    String? phone,
    String? serviceType,
    String? address,
    double? latitude,
    double? longitude,
    bool? isOpen,
    String? status,
    double? rating,
    String? role,
    DateTime? createdAt,
    String? shopPhoto,
    Map<String, dynamic>? documents,
    bool? onboardingCompleted,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? approvedAt,
  }) {
    return ShopModel(
      uid: uid ?? this.uid,
      ownerName: ownerName ?? this.ownerName,
      shopName: shopName ?? this.shopName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      serviceType: serviceType ?? this.serviceType,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isOpen: isOpen ?? this.isOpen,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      shopPhoto: shopPhoto ?? this.shopPhoto,
      documents: documents ?? this.documents,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
