import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  static const String keyId = 'rzp_test_TVDh4fnD14BmyG';

  late final Razorpay _razorpay;

  Function(PaymentSuccessResponse)? onSuccess;
  Function(PaymentFailureResponse)? onFailure;
  Function(ExternalWalletResponse)? onExternalWallet;

  RazorpayService({
    this.onSuccess,
    this.onFailure,
    this.onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _initListeners();
  }

  void _initListeners() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('Razorpay Success: ${response.paymentId}');
    onSuccess?.call(response);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay Error: ${response.code} | ${response.message}');
    onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('Razorpay External Wallet: ${response.walletName}');
    onExternalWallet?.call(response);
  }

  /// Opens Razorpay payment sheet.
  /// [amount] is in Indian Rupees (INR) and will be converted to paise.
  void openCheckout({
    required double amount,
    required String name,
    required String description,
    String? contact,
    String? email,
    String? orderId,
    Map<String, dynamic>? notes,
  }) {
    // Amount in paise (1 INR = 100 paise)
    final int amountInPaise = (amount * 100).round();

    final options = {
      'key': keyId,
      'amount': amountInPaise,
      'name': name,
      'description': description,
      'currency': 'INR',
      'timeout': 180, // 3 minutes timeout
      if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
      'prefill': {
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      'theme': {
        'color': '#2029C5', // Urban Services primary theme color
      },
      'retry': {
        'enabled': true,
        'max_count': 1,
      },
      'send_sms_hash': true,
      'config': {
        'display': {
          'blocks': {
            'upi': {
              'name': 'Pay using UPI',
              'instruments': [
                {
                  'method': 'upi',
                },
              ],
            },
            'other': {
              'name': 'Other Payment Options',
              'instruments': [
                {'method': 'card'},
                {'method': 'netbanking'},
                {'method': 'wallet'},
              ],
            },
          },
          'sequence': ['block.upi', 'block.other'],
          'preferences': {
            'show_default_blocks': true,
          },
        },
      },
      if (notes != null) 'notes': notes,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
      onFailure?.call(
        PaymentFailureResponse(
          Razorpay.UNKNOWN_ERROR,
          'Unable to open payment gateway: $e',
          null,
        ),
      );
    }
  }

  void dispose() {
    _razorpay.clear();
  }

  /// Request a refund via the backend API.
  static Future<Map<String, dynamic>?> requestRefund({
    required String paymentId,
    double? amount,
    String? bookingId,
    String? reason,
    String backendBaseUrl = 'https://urban-services-backend.vercel.app/api',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/razorpay/refund'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentId': paymentId,
          if (amount != null) 'amount': amount,
          if (bookingId != null) 'bookingId': bookingId,
          if (reason != null) 'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Refund API failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error requesting refund: $e');
      return null;
    }
  }

  /// Fetch payment details from Razorpay via the backend API.
  static Future<Map<String, dynamic>?> fetchPaymentDetails({
    required String paymentId,
    String backendBaseUrl = 'https://urban-services-backend.vercel.app/api',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$backendBaseUrl/razorpay/payment?paymentId=$paymentId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Fetch payment failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching payment details: $e');
      return null;
    }
  }
}
