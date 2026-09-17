import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final maintenanceProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('maintenance')
      .doc('system')
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      return data['maintenanceMode'] ?? false;
    }
    return false;
  });
});
