import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookmarkManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Local cache to keep existing UI working synchronously where possible
  // In a real app, this should be handled by a Riverpod provider
  static final List<Map<String, dynamic>> bookmarkedServices = [];

  static bool isBookmarked(String title) {
    return bookmarkedServices.any((s) => s['title'] == title);
  }

  static Future<void> toggleBookmark(Map<String, dynamic> service) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarked')
        .doc(service['title']);

    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      bookmarkedServices.removeWhere((s) => s['title'] == service['title']);
    } else {
      await docRef.set({
        ...service,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
      bookmarkedServices.add(service);
    }
  }

  static Future<void> fetchBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarked')
        .orderBy('bookmarkedAt', descending: true)
        .get();

    bookmarkedServices.clear();
    for (var doc in snapshot.docs) {
      bookmarkedServices.add(doc.data());
    }
  }
}
