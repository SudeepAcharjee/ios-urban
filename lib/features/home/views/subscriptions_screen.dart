import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/services/razorpay_service.dart';
import '../../../core/utils/custom_toast.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  static const Color primaryColor = Color(0xFF2029C5);
  late final RazorpayService _razorpayService;

  Map<String, dynamic>? _selectedPlanForCheckout;
  int _selectedIntervalDays = 7;
  String _selectedTimeSlot = '10:00 AM';
  final TextEditingController _addressController = TextEditingController();
  bool _enableAutopay = true;
  bool _isProcessingPayment = false;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final addr = data['address'] ?? data['location'] ?? '';
        if (addr.isNotEmpty) {
          _addressController.text = addr.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isProcessingPayment = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _selectedPlanForCheckout == null) {
        CustomToast.error(context, 'Unable to complete subscription.');
        return;
      }

      final plan = _selectedPlanForCheckout!;
      final double price = (plan['price'] as num?)?.toDouble() ?? 0.0;
      final int cycleDays = (plan['billingCycleDays'] as num?)?.toInt() ?? 30;

      final now = DateTime.now();
      final nextBooking = now.add(Duration(days: _selectedIntervalDays));
      final nextBilling = now.add(Duration(days: cycleDays));
      final expiry = nextBilling.add(const Duration(days: 1));

      // Get user name and phone
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['userName'] ?? user.displayName ?? 'Customer';
      final userPhone = userData['phone'] ?? user.phoneNumber ?? '';

      // 1. Create active subscription document
      final newSubRef = await FirebaseFirestore.instance.collection('user_subscriptions').add({
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email ?? '',
        'userPhone': userPhone,
        'planId': plan['id'],
        'planName': plan['name'] ?? 'Subscription',
        'planPrice': price,
        'billingCycleDays': cycleDays,
        'serviceId': plan['serviceId'] ?? '',
        'serviceName': plan['serviceName'] ?? '',
        'serviceImage': plan['serviceImage'] ?? '',
        'autoBookingIntervalDays': _selectedIntervalDays,
        'preferredTimeSlot': _selectedTimeSlot,
        'address': {'address': _addressController.text.trim()},
        'startDate': FieldValue.serverTimestamp(),
        'nextBookingDate': Timestamp.fromDate(nextBooking),
        'nextBillingDate': Timestamp.fromDate(nextBilling),
        'expiryDate': Timestamp.fromDate(expiry),
        'status': 'active',
        'autopay': _enableAutopay,
        'autoRenewCount': 0,
        'bookingHistory': [],
        'paymentStatus': 'paid',
        'paymentMethod': 'razorpay',
        'razorpayPaymentId': response.paymentId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Log transaction in subscription_transactions
      await FirebaseFirestore.instance.collection('subscription_transactions').add({
        'subscriptionId': newSubRef.id,
        'userId': user.uid,
        'userName': userName,
        'planName': plan['name'] ?? 'Subscription',
        'amount': price,
        'type': 'initial_payment',
        'status': 'succeeded',
        'paymentMethod': 'razorpay',
        'razorpayPaymentId': response.paymentId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isProcessingPayment = false);
        _showSuccessDialog(plan['name'] ?? 'Subscription', nextBooking);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        CustomToast.error(context, 'Failed to activate subscription: $e');
      }
    }
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      CustomToast.error(context, response.message ?? 'Payment failed or was cancelled');
    }
  }

  void _openCheckoutSheet(Map<String, dynamic> plan) {
    _selectedPlanForCheckout = plan;
    final allowed = (plan['allowedIntervals'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [7, 14, 30];

    setState(() {
      _selectedIntervalDays = allowed.isNotEmpty ? allowed.first : 7;
      if (_addressController.text.isEmpty) {
        _addressController.text = 'Doorstep Address';
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
          final planName = plan['name'] ?? 'Subscription';
          final serviceName = plan['serviceName'] ?? 'Selected Service';

          final bottomSafe = MediaQuery.of(modalContext).padding.bottom;
          final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              (bottomSafe > 0 ? bottomSafe + 20 : 32) + bottomInset,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.autorenew_rounded, color: primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              serviceName,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Choose Cadence
                  const Text(
                    'Auto-Booking Cadence',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your service will automatically be booked at this frequency:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allowed.map((interval) {
                      final bool isSelected = _selectedIntervalDays == interval;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedIntervalDays = interval);
                          setState(() => _selectedIntervalDays = interval);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            'Every $interval Days ${interval == 7 ? '(Weekly)' : interval == 30 ? '(Monthly)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Preferred Time Slot
                  const Text(
                    'Preferred Time Slot',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['09:00 AM', '10:00 AM', '12:00 PM', '02:00 PM', '04:00 PM'].map((slot) {
                      final bool isSelected = _selectedTimeSlot == slot;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() => _selectedTimeSlot = slot);
                          setState(() => _selectedTimeSlot = slot);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor.withValues(alpha: 0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? primaryColor : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? primaryColor : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Address Input
                  const Text(
                    'Doorstep Service Address',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _addressController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Enter street, building, city',
                        border: InputBorder.none,
                        icon: Icon(Icons.location_on_outlined, size: 20, color: primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Auto-Pay Switch
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Recurring Auto-Pay',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Auto-renews subscription fee when the period ends',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enableAutopay,
                          activeColor: primaryColor,
                          onChanged: (val) {
                            setModalState(() => _enableAutopay = val);
                            setState(() => _enableAutopay = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Razorpay Pay Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingPayment
                          ? null
                          : () {
                              Navigator.pop(modalContext);
                              _startRazorpayCheckout(plan);
                            },
                      icon: const Icon(Icons.credit_card, size: 20),
                      label: const Text(
                        'Pay Now',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Secured by Razorpay • UPI, Cards, NetBanking',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startRazorpayCheckout(Map<String, dynamic> plan) {
    final user = FirebaseAuth.instance.currentUser;
    final double price = (plan['price'] as num?)?.toDouble() ?? 0.0;
    final String planName = plan['name'] ?? 'Subscription';

    _razorpayService.openCheckout(
      amount: price,
      name: 'Urban Service',
      description: '$planName Subscription',
      email: user?.email ?? '',
      contact: user?.phoneNumber ?? '',
      notes: {
        'planId': plan['id'],
        'planName': planName,
        'userId': user?.uid ?? '',
        'intervalDays': _selectedIntervalDays,
      },
    );
  }

  void _showSuccessDialog(String planName, DateTime nextBooking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Subscribed!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have successfully subscribed to "$planName".',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'First automated visit scheduled for ${DateFormat('dd MMM yyyy').format(nextBooking)} at $_selectedTimeSlot.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Service Subscriptions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. User Active Subscription Banner (if any)
          if (user != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('user_subscriptions')
                  .where('userId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final sub = snapshot.data!.docs.first.data();
                final planName = sub['planName'] ?? 'Active Plan';
                final serviceName = sub['serviceName'] ?? 'Service';
                final intervalDays = sub['autoBookingIntervalDays'] ?? 7;
                final nextBookingTs = sub['nextBookingDate'] as Timestamp?;
                final nextBookingDate = nextBookingTs?.toDate();

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2029C5), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2029C5).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'ACTIVE SUBSCRIBER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${sub['planPrice'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        planName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        serviceName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Auto-Booked every $intervalDays days • Next: ${nextBookingDate != null ? DateFormat('dd MMM').format(nextBookingDate) : 'Upcoming'}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Title Section
          const Text(
            'Explore Subscription Plans',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Never worry about booking again. Get automated doorstep servicing on your schedule.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 16),

          // 2. Stream all Active Plans from Firestore
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('subscriptions')
                .where('status', isEqualTo: 'Active')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Subscription Plans Available',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'New plans are currently being configured by our workshop team. Please check back shortly!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: docs.map((docSnap) {
                  final data = docSnap.data();
                  data['id'] = docSnap.id;

                  final planName = (data['name'] ?? 'Plan').toString();
                  final tag = (data['tag'] ?? '').toString();
                  final price = (data['price'] as num?)?.toDouble() ?? 0.0;
                  final cycle = (data['billingCycleName'] ?? 'monthly').toString();
                  final serviceName = (data['serviceName'] ?? 'Service').toString();
                  final serviceImage = (data['serviceImage'] ?? '').toString();
                  final allowedIntervals = (data['allowedIntervals'] as List<dynamic>?)
                          ?.map((e) => (e as num).toInt())
                          .toList() ??
                      [7, 14, 30];
                  final features = (data['features'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag & Price Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (tag.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tag.toUpperCase(),
                                  style: const TextStyle(
                                    color: primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  ' / $cycle',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Plan Name
                        Text(
                          planName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Service preview card
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: serviceImage.isNotEmpty
                                    ? Image.network(
                                        serviceImage,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildFallbackServiceIcon(),
                                      )
                                    : _buildFallbackServiceIcon(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'COVERED SERVICE',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    Text(
                                      serviceName,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cadence pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF3B82F6)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Auto-Booking Options: Every ${allowedIntervals.join(', ')} Days',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Feature bullet points
                        ...features.map((feat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feat,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 16),

                        // Subscribe CTA Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _openCheckoutSheet(data),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Subscribe',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackServiceIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.car_crash_rounded, color: primaryColor, size: 22),
    );
  }
}
