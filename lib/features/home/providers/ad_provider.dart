import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ad_model.dart';

final adProvider = StreamProvider<List<AdModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('ads')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => AdModel.fromMap(doc.data(), doc.id)).toList();
  });
});
