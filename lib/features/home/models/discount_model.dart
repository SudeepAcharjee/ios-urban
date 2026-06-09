
class DiscountModel {
  final String id;
  final String code;
  final String type; // 'percentage' or 'fixed'
  final int value;
  final String imageUrl;
  final String appliesTo;
  final String serviceName;
  final String categoryName;
  final int minRequirement;
  final String startDate;
  final String endDate;
  final String status;

  DiscountModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.imageUrl,
    required this.appliesTo,
    required this.serviceName,
    required this.categoryName,
    required this.minRequirement,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory DiscountModel.fromMap(Map<String, dynamic> map, String id) {
    return DiscountModel(
      id: id,
      code: map['code'] ?? '',
      type: map['type'] ?? 'percentage',
      value: (map['value'] ?? 0).toInt(),
      imageUrl: map['imageUrl'] ?? '',
      appliesTo: map['appliesTo'] ?? 'all',
      serviceName: map['serviceName'] ?? '',
      categoryName: map['categoryName'] ?? '',
      minRequirement: (map['minRequirement'] ?? 0).toInt(),
      startDate: map['startDate'] ?? '',
      endDate: map['endDate'] ?? '',
      status: map['status'] ?? 'active',
    );
  }

  // Helper getters for UI
  String get displayTitle {
    if (serviceName.isNotEmpty) return serviceName;
    if (categoryName.isNotEmpty) return '$categoryName Special';
    return 'Special Discount';
  }

  String get displaySubtitle {
    if (type == 'percentage') return '$value% OFF';
    return 'Flat ₹$value OFF';
  }

  String get displayFooter {
    return 'Min. requirement ₹$minRequirement | T&C Applied';
  }

  bool get isExpired {
    if (endDate.isEmpty) return false;
    try {
      final endDateTime = DateTime.parse(endDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return today.isAfter(endDateTime);
    } catch (e) {
      return false;
    }
  }
}
