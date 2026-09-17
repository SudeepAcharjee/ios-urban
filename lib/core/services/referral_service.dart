import 'dart:math';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a unique 8-character uppercase referral code
  static String generateCode(String? name, String uid) {
    String cleanName = (name ?? 'USER')
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    if (cleanName.length < 3) cleanName = 'URBAN';
    final prefix = cleanName.substring(0, min(4, cleanName.length));

    final random = Random();
    final numPart = (1000 + random.nextInt(9000)).toString();
    return '$prefix$numPart';
  }

  /// Get or create user's personal referral code in Firestore
  static Future<String> getOrCreateReferralCode(String uid, {String? name}) async {
    final userRef = _firestore.collection('users').doc(uid);
    final doc = await userRef.get();

    if (doc.exists && doc.data()?['referralCode'] != null) {
      return doc.data()!['referralCode'].toString();
    }

    final newCode = generateCode(name ?? doc.data()?['name']?.toString(), uid);
    await userRef.set({
      'referralCode': newCode,
    }, SetOptions(merge: true));

    return newCode;
  }

  /// Build shareable invite link & message
  static String buildInviteMessage(String referralCode, String? userName) {
    final displayName = userName != null && userName.isNotEmpty ? userName : 'Your friend';
    return '🚗 $displayName has invited you to Urban Services!\n\n'
        '🎁 Use invite code: $referralCode\n'
        '✨ Get 10% OFF on your service booking!\n\n'
        'Download & open the app to claim your discount:\n'
        'https://urbanservices.app/invite?code=$referralCode\n\n'
        'Direct app link: urbanservice://invite?code=$referralCode';
  }

  /// Open native Share sheet with invite link
  static Future<void> shareInviteLink({
    required String referralCode,
    String? userName,
  }) async {
    final message = buildInviteMessage(referralCode, userName);
    await Share.share(
      message,
      subject: 'Get 10% OFF on Urban Services!',
    );
  }

  /// Copy referral code to clipboard
  static Future<void> copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
  }

  /// Extract code from link or text (e.g. ?code=PRAN1234 or plain code)
  static String? extractReferralCode(String text) {
    if (text.isEmpty) return null;

    // 1. Check URI query parameters (code=... or ref=...)
    try {
      final uri = Uri.tryParse(text.trim());
      if (uri != null && uri.hasQuery) {
        if (uri.queryParameters.containsKey('code')) {
          return uri.queryParameters['code']?.trim().toUpperCase();
        }
        if (uri.queryParameters.containsKey('ref')) {
          return uri.queryParameters['ref']?.trim().toUpperCase();
        }
      }
    } catch (_) {}

    // 2. Check regex pattern for code in text: code: ABC1234 or code=ABC1234
    final paramMatch = RegExp(r'(?:code|ref)[=:]\s*([A-Z0-9]{5,10})', caseSensitive: false).firstMatch(text);
    if (paramMatch != null) {
      return paramMatch.group(1)?.toUpperCase();
    }

    // 3. Check if whole text is a clean 6-10 character alphanumeric code
    final clean = text.trim().toUpperCase();
    if (RegExp(r'^[A-Z]{3,5}[0-9]{3,5}$').hasMatch(clean)) {
      return clean;
    }

    return null;
  }

  /// Inspect clipboard for copied referral code/link
  static Future<String?> checkClipboardForCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null) {
        return extractReferralCode(data.text!);
      }
    } catch (_) {}
    return null;
  }

  /// Apply referral code: Validates, creates 10% coupons for BOTH referrer and referee
  static Future<Map<String, dynamic>> applyReferralCode({
    required String code,
    required String currentUserId,
    String? currentUserName,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw 'Please enter a referral code';
    }

    // 1. Check current user status
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final currentUserData = currentUserDoc.data() ?? {};

    if (currentUserData['referredBy'] != null) {
      throw 'You have already applied a referral code!';
    }

    if (currentUserData['referralCode'] == cleanCode) {
      throw 'You cannot use your own referral code!';
    }

    // 2. Look up Referrer by code
    final referrerQuery = await _firestore
        .collection('users')
        .where('referralCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      throw 'Invalid referral code. Please check and try again.';
    }

    final referrerDoc = referrerQuery.docs.first;
    final referrerId = referrerDoc.id;
    final referrerData = referrerDoc.data();
    final referrerName = referrerData['name'] ?? 'Friend';

    if (referrerId == currentUserId) {
      throw 'You cannot use your own referral code!';
    }

    final randSuffix = (100 + Random().nextInt(900)).toString();
    final refereeCode = 'WELCOME10-${cleanCode.substring(0, min(4, cleanCode.length))}$randSuffix';
    final referrerRewardCode = 'REF10-${cleanCode.substring(0, min(4, cleanCode.length))}$randSuffix';

    final batch = _firestore.batch();

    // 3. Award Referee (Current User) 10% Discount Coupon
    final refereeCouponRef = _firestore.collection('discounts').doc();
    batch.set(refereeCouponRef, {
      'code': refereeCode,
      'type': 'percentage',
      'value': 10,
      'appliesTo': 'all',
      'serviceName': 'Friend Invite Bonus',
      'categoryName': 'Referral',
      'minRequirement': 0,
      'status': 'active',
      'userId': currentUserId,
      'forUserOnly': true,
      'isReferralReward': true,
      'description': '10% OFF on any booking (Invited by $referrerName)',
      'createdAt': FieldValue.serverTimestamp(),
      'startDate': DateTime.now().toIso8601String(),
      'endDate': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
    });

    // 4. Award Referrer 10% Discount Coupon
    final referrerCouponRef = _firestore.collection('discounts').doc();
    final refereeName = currentUserName ?? currentUserData['name'] ?? 'New Member';
    batch.set(referrerCouponRef, {
      'code': referrerRewardCode,
      'type': 'percentage',
      'value': 10,
      'appliesTo': 'all',
      'serviceName': 'Referral Reward',
      'categoryName': 'Referral',
      'minRequirement': 0,
      'status': 'active',
      'userId': referrerId,
      'forUserOnly': true,
      'isReferralReward': true,
      'description': '10% OFF on any booking for inviting $refereeName',
      'createdAt': FieldValue.serverTimestamp(),
      'startDate': DateTime.now().toIso8601String(),
      'endDate': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
    });

    // 5. Create Referral Audit Record
    final referralRef = _firestore.collection('referrals').doc();
    batch.set(referralRef, {
      'referrerId': referrerId,
      'referrerName': referrerName,
      'referrerPhone': referrerData['phone'] ?? '',
      'refereeId': currentUserId,
      'refereeName': refereeName,
      'refereePhone': currentUserData['phone'] ?? '',
      'referralCode': cleanCode,
      'status': 'rewarded',
      'discountPercent': 10,
      'refereeCouponCode': refereeCode,
      'referrerCouponCode': referrerRewardCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 6. Update Current User Record
    batch.update(_firestore.collection('users').doc(currentUserId), {
      'referredBy': referrerId,
      'referralCodeUsed': cleanCode,
      'referredAt': FieldValue.serverTimestamp(),
    });

    // 7. Increment Referrer Count
    batch.update(_firestore.collection('users').doc(referrerId), {
      'referralsCount': FieldValue.increment(1),
    });

    await batch.commit();

    return {
      'referrerName': referrerName,
      'refereeCoupon': refereeCode,
      'discountPercent': 10,
    };
  }

  /// Mark referral coupon as used when booking is confirmed
  static Future<void> markCouponUsed(String couponCode, String userId) async {
    try {
      final snap = await _firestore
          .collection('discounts')
          .where('code', isEqualTo: couponCode)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'status': 'used',
          'usedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }
}
