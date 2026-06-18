import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coupons_screen.dart';
import 'add_address_screen.dart';
import 'bookings_screen.dart';
import 'package:car_washing_service_app/features/home/providers/address_provider.dart';
import 'package:car_washing_service_app/features/home/providers/discount_provider.dart';
import 'package:car_washing_service_app/features/home/models/discount_model.dart';
import 'package:intl/intl.dart';
import '../../../core/services/location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BookAWashScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String title;
  final int price;
  final String serviceId;
  final String categoryId;
  final String categoryName;

  const BookAWashScreen({
    super.key,
    required this.imagePath,
    required this.title,
    required this.price,
    required this.serviceId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  ConsumerState<BookAWashScreen> createState() => _BookAWashScreenState();
}

class _BookAWashScreenState extends ConsumerState<BookAWashScreen> {
  int _currentStep =
      0; // 0: Summary, 1: Date & Time, 2: Details, 3: Payment, 4: Confirmed
  int _quantity = 1;
  String? _appliedCoupon;
  DiscountModel? _selectedDiscount;
  int _selectedDateIndex = -1;
  String? _selectedDateString;
  String? _selectedTime;
  int _confirmationStage =
      0; // 0: Tick Centered, 1: Texts, 2: Details Card, 3: Buttons
  bool _isSaving = false;
  bool _isLocating = false;
  String _selectedAddress = 'Select Address';
  String _selectedPaymentMethod = 'Cash';
  String? _fetchedCurrentLocation;
  String? _bookingId;
  String? _logDocId;

  @override
  void initState() {
    super.initState();
    _createUserLog();
  }

  @override
  void dispose() {
    if (_currentStep != 2) {
      _updateUserLogStatus('not confirmed');
    }
    super.dispose();
  }

  Future<void> _createUserLog() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final logRef = FirebaseFirestore.instance.collection('users_logs').doc();
      _logDocId = logRef.id;

      await logRef.set({
        'logId': _logDocId,
        'userId': user.uid,
        'serviceId': widget.serviceId,
        'serviceTitle': widget.title,
        'price': widget.price,
        'status': 'not confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user log: $e');
    }
  }

  Future<void> _updateUserLogStatus(String status) async {
    if (_logDocId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users_logs')
          .doc(_logDocId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating user log status: $e');
    }
  }


  double get _itemTotal => (widget.price * _quantity).toDouble();

  double get _discountAmount {
    if (_selectedDiscount == null) return 0.0;
    if (_selectedDiscount!.type == 'percentage') {
      return (_itemTotal * _selectedDiscount!.value) / 100;
    } else {
      return _selectedDiscount!.value.toDouble();
    }
  }

  double get _platformFee => 0.0;
  double get _taxFee => 0.0;
  double get _gstFee => 0.0;
  double get _grandTotal =>
      _itemTotal + _platformFee + _taxFee + _gstFee - _discountAmount;

  Future<void> _saveBookingToFirestore() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final bookingId = FirebaseFirestore.instance
          .collection('bookings')
          .doc()
          .id;
      setState(() => _bookingId = bookingId);

      final bookingData = {
        'bookingId': bookingId,
        'userId': user.uid,
        'serviceId': widget.serviceId,
        'categoryId': widget.categoryId,
        'title': widget.title,
        'imagePath': widget.imagePath,
        'price': widget.price,
        'quantity': _quantity,
        'totalPrice': _grandTotal,
        'coupon': _appliedCoupon,
        'discountAmount': _discountAmount,
        'dateIndex': _selectedDateIndex,
        'date': _selectedDateString,
        'time': _selectedTime,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'address': _selectedAddress,
        'paymentMethod': _selectedPaymentMethod,
      };

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set(bookingData);

      await _updateUserLogStatus('booked');

      // 📧 Send Confirmation Email
      try {
        String? targetEmail = user.email;

        // Fetch email from Firestore if missing from Auth (Phone Auth case)
        if (targetEmail == null || targetEmail.isEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            targetEmail = userDoc.data()?['email'];
          } else {
            final workerDoc = await FirebaseFirestore.instance
                .collection('workers')
                .doc(user.uid)
                .get();
            if (workerDoc.exists) {
              targetEmail = workerDoc.data()?['email'];
            }
          }
        }

        if (targetEmail != null && targetEmail.isNotEmpty) {
          const String backendUrl =
              'https://urban-services-backend.vercel.app/api';
          final response = await http.post(
            Uri.parse('$backendUrl/send-booking-confirmation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': targetEmail,
              'bookingDetails': {
                'bookingId': bookingId,
                'serviceName': widget.title,
                'customerName': user.displayName ?? 'Customer',
                'date': _selectedDateString ?? 'TBD',
                'time': _selectedTime ?? 'TBD',
                'price': _itemTotal.toInt(),
                'discount': _discountAmount.toInt(),
                'total': _grandTotal.toInt(),
              },
            }),
          );

          if (response.statusCode == 200) {
            debugPrint('Booking confirmation email sent to $targetEmail');
          } else {
            debugPrint('Backend email error: ${response.body}');
          }
        }
      } catch (e) {
        debugPrint('Error sending confirmation email: $e');
      }

      if (mounted) {
        setState(() {
          _currentStep = 2;
          _isSaving = false;

          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) setState(() => _confirmationStage = 1);
          });
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (mounted) setState(() => _confirmationStage = 2);
          });
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _confirmationStage = 3);
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save booking: $e')));
      }
    }
  }

  Widget _buildSummaryStep() {
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const primaryColor = Color(0xFF2029C5);

    return Column(
      key: const ValueKey<int>(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🛍️ Service Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: widget.imagePath.startsWith('http')
                    ? Image.network(
                        widget.imagePath,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 110,
                          height: 110,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Image.asset(
                        widget.imagePath,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${widget.price}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(14),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.remove,
                                    size: 18,
                                    color: _quantity > 1
                                        ? textPrimary
                                        : textSecondary,
                                  ),
                                  onPressed: () {
                                    if (_quantity > 1)
                                      setState(() => _quantity--);
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  onPressed: () => setState(() => _quantity++),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),
        // 🏷️ Apply Coupon
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CouponsScreen(
                  serviceName: widget.title,
                  categoryName: widget.categoryName,
                  serviceId: widget.serviceId,
                  categoryId: widget.categoryId,
                ),
              ),
            );
            if (result != null && result is String) {
              final discountsAsync = ref.read(discountProvider);
              final discounts = discountsAsync.value ?? [];
              try {
                final discount = discounts.firstWhere((d) => d.code == result);

                if (discount.status != 'active') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coupon is no longer active')),
                  );
                  return;
                }

                if (discount.isExpired) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coupon has expired')),
                  );
                  return;
                }

                setState(() {
                  _appliedCoupon = result;
                  _selectedDiscount = discount;
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid coupon code')),
                );
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.percent_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 15),
                Text(
                  _appliedCoupon ?? 'Apply Coupon',
                  style: TextStyle(
                    fontSize: 16,
                    color: _appliedCoupon != null
                        ? primaryColor
                        : textSecondary,
                    fontWeight: _appliedCoupon != null
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_appliedCoupon != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _appliedCoupon = null;
                        _selectedDiscount = null;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: primaryColor,
                      size: 20,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: textSecondary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),

        // 💰 Price Breakdown Container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSummaryPriceRow('Item Total', '₹${_itemTotal.toInt()}'),
              const SizedBox(height: 14),
              _buildSummaryPriceRow(
                'Platform Fee',
                _platformFee == 0 ? 'Free' : '₹${_platformFee.toInt()}',
                isFree: _platformFee == 0,
              ),
              const SizedBox(height: 14),
              _buildSummaryPriceRow('Visiting Fee', 'Free', isFree: true),
              const SizedBox(height: 14),
              _buildSummaryPriceRow('GST', '₹${_gstFee.toInt()}'),
              const SizedBox(height: 14),
              _buildSummaryPriceRow('Delivery Fee', 'Free', isFree: true),

              if (_discountAmount > 0) ...[
                const SizedBox(height: 14),
                _buildSummaryPriceRow(
                  'Discount',
                  '-₹${_discountAmount.toInt()}',
                  isDiscount: true,
                ),
              ],

              const SizedBox(height: 20),
              // Dashed Divider
              Row(
                children: List.generate(
                  150 ~/ 2,
                  (index) => Expanded(
                    child: Container(
                      color: index % 2 == 0
                          ? Colors.transparent
                          : Colors.grey.withOpacity(0.2),
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Grand Total',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '₹${_grandTotal.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSummaryPriceRow(
    String label,
    String value, {
    bool isFree = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: (isFree || isDiscount)
                ? const Color(0xFF10B981)
                : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      key: const ValueKey<int>(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _buildPaymentSectionHeader('Pay After Service'),
        _buildPaymentTile(
          'Pay With Cash After Service',
          '',
          'Cash',
          iconData: Icons.money,
          iconColor: Colors.green,
        ),
        const SizedBox(height: 20),
        _buildPaymentSectionHeader('Debit or Credit Card'),
        _buildPaymentTile(
          'Master Card',
          '4897 4700 2589 9658',
          'Card',
          isComingSoon: true,
          logo: Container(
            width: 40,
            height: 25,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildPaymentSectionHeader('Wallet'),
        _buildPaymentTile(
          'Paytm',
          '',
          'Paytm',
          iconData: Icons.account_balance_wallet_outlined,
          iconColor: Colors.blue,
          isComingSoon: true,
        ),
        _buildPaymentTile(
          'Amazon Pay',
          '',
          'Amazon',
          iconData: Icons.payment,
          iconColor: Colors.orange,
          isComingSoon: true,
        ),
        const SizedBox(height: 20),
        _buildPaymentSectionHeader('UPI'),
        _buildPaymentTile(
          'Paytm UPI',
          '',
          'UPI_Paytm',
          iconData: Icons.account_balance,
          iconColor: Colors.blue,
          isComingSoon: true,
        ),
        _buildPaymentTile(
          'Google Pay',
          '',
          'UPI_GPay',
          logo: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('images/logo/google.png'),
          ),
          isComingSoon: true,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildPaymentSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildPaymentTile(
    String title,
    String subtitle,
    String methodValue, {
    Widget? logo,
    IconData? iconData,
    Color? iconColor,
    double iconSize = 24,
    bool isComingSoon = false,
  }) {
    bool isSelected = _selectedPaymentMethod == methodValue;

    return Opacity(
      opacity: isComingSoon ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2029C5) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading:
                logo ??
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (iconColor ?? Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: iconColor, size: iconSize),
                ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (isComingSoon) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2029C5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Color(0xFF2029C5),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: subtitle.isNotEmpty
                ? Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: isComingSoon
                ? null
                : Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? const Color(0xFF2029C5)
                        : Colors.grey.shade400,
                    size: 22,
                  ),
            onTap: isComingSoon
                ? null
                : () {
                    setState(() => _selectedPaymentMethod = methodValue);
                  },
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedStep() {
    return SingleChildScrollView(
      child: Center(
        key: const ValueKey<int>(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B8AFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6B8AFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _confirmationStage >= 1 ? 1.0 : 0.0,
              child: Column(
                children: [
                  const Text(
                    'Success! Your booking is\nregistered.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Color(0xFF1F2937),
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Please check your app for confirmation and further instructions about the service.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            AnimatedOpacity(
              duration: const Duration(milliseconds: 600),
              opacity: _confirmationStage >= 2 ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      _buildTicketRow(
                        'Booking Number',
                        _bookingId?.substring(0, 8).toUpperCase() ?? 'NEW-BOOK',
                      ),
                      const SizedBox(height: 16),
                      _buildTicketRow(
                        'Booking Date',
                        DateFormat('d MMMM yyyy').format(DateTime.now()),
                      ),
                      const SizedBox(height: 16),
                      _buildTicketRow('Service Name', widget.title),
                      const SizedBox(height: 16),
                      _buildTicketRow(
                        'Service Date',
                        _selectedDateString ?? 'Today',
                      ),
                      const SizedBox(height: 16),
                      _buildTicketRow(
                        'Service Time',
                        _selectedTime ?? '08:00 AM',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConfirmed = _currentStep == 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isConfirmed
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                onPressed: () {
                  if (_currentStep > 0) {
                    setState(() {
                      _currentStep--;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              title: Text(
                _currentStep == 0 ? 'Booking Summary' : 'Payment Method',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isConfirmed) _buildStepIndicator(),
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: Container(
                        key: ValueKey<int>(_currentStep),
                        child: _currentStep == 0
                            ? _buildSummaryStep()
                            : _currentStep == 1
                            ? _buildPaymentStep()
                            : _buildConfirmedStep(),
                      ),
                    ),
                  ),
                  if (_isSaving)
                    Container(
                      color: Colors.white.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildFooter(isConfirmed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 30),
      child: Row(
        children: [
          _buildStepCircle(0, 'Summary'),
          _buildStepLine(0),
          _buildStepCircle(1, 'Payment'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    bool isCompleted = _currentStep > step;
    const primaryColor = Color(0xFF2029C5);

    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? primaryColor : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : step == 0 && _currentStep == 0
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey.shade400,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
            color: isActive ? primaryColor : Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    bool isActive = _currentStep > afterStep;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 10, right: 10, bottom: 22),
        height: 2,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(1),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: isActive ? 1.0 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2029C5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isConfirmed) {
    const primaryColor = Color(0xFF2029C5);

    if (isConfirmed) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _confirmationStage >= 3 ? 1.0 : 0.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingsScreen(),
                    ),
                    (route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'View Booking',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                'Back to Home',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    bool isSlotSelected = _selectedDateIndex != -1 && _selectedTime != null;
    bool isAddressSelected = _selectedAddress != 'Select Address';

    Widget footerButton;
    if (_currentStep == 0) {
      if (!isSlotSelected) {
        footerButton = ElevatedButton(
          onPressed: () => _showSlotSelectionSheet(),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today_rounded, size: 20),
              SizedBox(width: 12),
              Text(
                'Select Slot',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Spacer(),
              Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        );
      } else if (!isAddressSelected) {
        footerButton = ElevatedButton(
          onPressed: () => _showAddressSelectionSheet(),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_rounded, size: 20),
              SizedBox(width: 12),
              Text(
                'Select Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Spacer(),
              Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        );
      } else {
        footerButton = ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Pay Now',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 24),
            ],
          ),
        );
      }
    } else {
      footerButton = ElevatedButton(
        onPressed: _saveBookingToFirestore,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Confirm Booking',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: double.infinity, height: 60, child: footerButton),
        const SizedBox(height: 20),
        // Trust Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_rounded,
              color: primaryColor.withOpacity(0.5),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Secure Booking • 100% Safe & Reliable',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSlotSelectionSheet() {
    int tempDateIndex = _selectedDateIndex;
    String? tempDateString = _selectedDateString;
    String? tempTime = _selectedTime;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(context).padding.bottom + 36,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final dayName = DateFormat('E').format(date);
                      final dayNumber = DateFormat('d').format(date);
                      bool isSelected = tempDateIndex == index;

                      return GestureDetector(
                        onTap: () {
                          bool timeNeedsReset = false;
                          if (index == 0 && tempTime != null) {
                            try {
                              final parts = tempTime!.split(' ');
                              final timeParts = parts[0].split(':');
                              int hour = int.parse(timeParts[0]);
                              final int minute = int.parse(timeParts[1]);
                              final isPM = parts[1] == 'PM';

                              if (isPM && hour != 12) hour += 12;
                              if (!isPM && hour == 12) hour = 0;

                              final now = DateTime.now();
                              final slotTime = DateTime(
                                now.year,
                                now.month,
                                now.day,
                                hour,
                                minute,
                              );

                              if (slotTime.isBefore(now)) {
                                timeNeedsReset = true;
                              }
                            } catch (e) {
                              // Ignore
                            }
                          }

                          setModalState(() {
                            tempDateIndex = index;
                            tempDateString = DateFormat('d MMMM').format(date);
                            if (timeNeedsReset) tempTime = null;
                          });
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2029C5)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                index == 0 ? 'Today' : dayName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                dayNumber,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Select Time',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 15),
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: [
                    '08:00 AM',
                    '09:00 AM',
                    '10:00 AM',
                    '11:00 AM',
                    '12:00 PM',
                    '01:00 PM',
                    '02:00 PM',
                    '03:00 PM',
                    '04:00 PM',
                    '05:00 PM',
                    '06:00 PM',
                    '07:00 PM',
                    '08:00 PM',
                  ].length,
                  itemBuilder: (context, index) {
                    final times = [
                      '08:00 AM',
                      '09:00 AM',
                      '10:00 AM',
                      '11:00 AM',
                      '12:00 PM',
                      '01:00 PM',
                      '02:00 PM',
                      '03:00 PM',
                      '04:00 PM',
                      '05:00 PM',
                      '06:00 PM',
                      '07:00 PM',
                      '08:00 PM',
                    ];
                    final time = times[index];
                    bool isSelected = tempTime == time;

                    bool isDisabled = false;
                    if (tempDateIndex == 0) {
                      try {
                        final parts = time.split(' ');
                        final timeParts = parts[0].split(':');
                        int hour = int.parse(timeParts[0]);
                        final int minute = int.parse(timeParts[1]);
                        final isPM = parts[1] == 'PM';

                        if (isPM && hour != 12) hour += 12;
                        if (!isPM && hour == 12) hour = 0;

                        final now = DateTime.now();
                        final slotTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          hour,
                          minute,
                        );

                        if (slotTime.isBefore(now)) {
                          isDisabled = true;
                        }
                      } catch (e) {
                        // Ignore parsing errors
                      }
                    }

                    return GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () {
                              setModalState(() => tempTime = time);
                            },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2029C5)
                              : (isDisabled
                                    ? Colors.grey.shade300
                                    : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          time,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDisabled
                                      ? Colors.grey.shade500
                                      : Colors.black),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (tempDateIndex != -1 && tempTime != null)
                        ? () async {
                            try {
                              if (tempDateIndex == 0) {
                                // Show a small loading indicator or just do the check
                                final workersQuery = await FirebaseFirestore
                                    .instance
                                    .collection('workers')
                                    .where('status', isEqualTo: 'Available')
                                    .where(
                                      'serviceIds',
                                      arrayContains: widget.serviceId,
                                    )
                                    .limit(1)
                                    .get();

                                if (workersQuery.docs.isEmpty) {
                                  // 🚫 No workers available for this service right now
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                              size: 28,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'Peak Time!',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: const Text(
                                          'We are currently experiencing high demand and no workers are available for this service right now. Please try again later.',
                                          style: TextStyle(fontSize: 15),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                color: Color(0xFF2029C5),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return;
                                }
                              }
                            } catch (e) {
                              debugPrint(
                                'Error checking worker availability: $e',
                              );
                              // Proceed anyway or handle error? Proceeding is safer for UX unless it's critical
                            }

                            setState(() {
                              _selectedDateIndex = tempDateIndex;
                              _selectedDateString = tempDateString;
                              _selectedTime = tempTime;
                            });

                            Navigator.pop(context);
                            _showAddressSelectionSheet();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2029C5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Confirm Slot',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddressSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final addressesAsync = ref.watch(addressesProvider);

          return StatefulBuilder(
            builder: (context, setModalState) => Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).padding.bottom + 36,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAddressScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.add_location_alt_outlined,
                          color: Color(0xFF2029C5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_fetchedCurrentLocation != null) ...[
                    const Text(
                      'Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setModalState(() {
                          _selectedAddress = _fetchedCurrentLocation!;
                        });
                        setState(() {
                          _selectedAddress = _fetchedCurrentLocation!;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _selectedAddress == _fetchedCurrentLocation
                              ? const Color(0xFF2029C5).withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedAddress == _fetchedCurrentLocation
                                ? const Color(0xFF2029C5)
                                : Colors.grey.shade200,
                            width: _selectedAddress == _fetchedCurrentLocation
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2029C5).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF2029C5),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detected Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fetchedCurrentLocation!,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedAddress == _fetchedCurrentLocation)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF2029C5),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 15),
                  ],
                  Flexible(
                    child: addressesAsync.when(
                      data: (addresses) {
                        if (addresses.isEmpty &&
                            _fetchedCurrentLocation == null) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No addresses found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddAddressScreen(),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2029C5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Add Address'),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: addresses.length,
                          itemBuilder: (context, index) {
                            final addr = addresses[index];
                            final addressText =
                                addr['address'] ?? 'No address text';
                            final type = addr['type'] ?? 'Home';
                            bool isSelected = _selectedAddress == addressText;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedAddress = addressText);
                                setModalState(
                                  () => _selectedAddress = addressText,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFF2029C5,
                                        ).withOpacity(0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF2029C5)
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2029C5,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        type == 'Home'
                                            ? Icons.home_rounded
                                            : Icons.work_rounded,
                                        color: const Color(0xFF2029C5),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            type,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            addressText,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF2029C5)
                                              : Colors.grey.shade300,
                                          width: isSelected ? 6 : 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2029C5),
                        ),
                      ),
                      error: (err, stack) => Center(child: Text('Error: $err')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_selectedAddress != 'Select Address')
                          ? () {
                              setState(
                                () => _currentStep = 1,
                              ); // Move to payment
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2029C5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _isLocating
                        ? null
                        : () async {
                            setModalState(() => _isLocating = true);
                            try {
                              final position =
                                  await LocationService.getCurrentPosition();
                              if (position != null) {
                                final address =
                                    await LocationService.getAddressFromLatLng(
                                      position,
                                    );
                                if (address != null) {
                                  setModalState(() {
                                    _fetchedCurrentLocation = address;
                                  });
                                  setState(() {
                                    _fetchedCurrentLocation = address;
                                  });
                                }
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            } finally {
                              setModalState(() => _isLocating = false);
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2029C5).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLocating)
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2029C5),
                              ),
                            )
                          else
                            const Icon(
                              Icons.my_location,
                              color: Color(0xFF2029C5),
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _isLocating
                                ? 'Locating...'
                                : 'Use Current Location',
                            style: const TextStyle(
                              color: Color(0xFF2029C5),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
