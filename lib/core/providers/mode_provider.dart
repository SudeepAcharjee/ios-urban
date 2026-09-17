import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final modeProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('mode')
      .doc('system')
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      return data['offlineMode'] ?? false;
    }
    return false;
  });
});
