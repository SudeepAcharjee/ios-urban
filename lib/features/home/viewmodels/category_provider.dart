import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconUrl;
  final IconData fallbackIcon;
  final Color? color;
  final String status;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.fallbackIcon,
    required this.status,
    this.color,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    return CategoryModel(
      id: doc.id,
      name: name,
      iconUrl: data['iconUrl'] ?? '',
      fallbackIcon: _getIconData(data['icon'] ?? '', name),
      status: data['status'] ?? 'active',
      color: data['color'] != null ? Color(int.parse(data['color'])) : null,
    );
  }

  static IconData _getIconData(String iconName, String categoryName) {
    final String key = iconName.toLowerCase().trim();
    final String name = categoryName.toLowerCase().trim();

    // 1. Check icon field first
    if (key == 'car' || key.contains('directions_car')) return Icons.directions_car_filled;
    if (key == 'bike' || key.contains('two_wheeler') || key == 'motorcycle') return Icons.two_wheeler;
    if (key == 'electrical' || key.contains('electric') || key == 'bolt') return Icons.electrical_services;
    if (key == 'cleaning' || key == 'wash') return Icons.local_car_wash;
    if (key == 'plumbing' || key == 'water') return Icons.plumbing;
    if (key == 'ac' || key == 'cooling') return Icons.ac_unit;
    if (key == 'painting' || key == 'paint') return Icons.format_paint;
    if (key == 'carpenter' || key == 'wood') return Icons.handyman;

    // 2. Fallback: Identify based on Category Name
    if (name.contains('car')) return Icons.directions_car_filled;
    if (name.contains('bike') || name.contains('scoot')) return Icons.two_wheeler;
    if (name.contains('elect') || name.contains('repair')) return Icons.electrical_services;
    if (name.contains('wash') || name.contains('clean')) return Icons.local_car_wash;
    if (name.contains('plumb')) return Icons.plumbing;
    if (name.contains('ac') || name.contains('air')) return Icons.ac_unit;
    if (name.contains('paint')) return Icons.format_paint;
    if (name.contains('home') || name.contains('repair')) return Icons.home_repair_service;

    return Icons.category_outlined;
  }
}

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList());
});
