import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';

final discountProvider = StreamProvider<List<DiscountModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('discounts')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DiscountModel.fromMap(doc.data(), doc.id))
          .toList());
});
