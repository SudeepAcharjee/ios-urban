import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:toastification/toastification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkerPaymentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> taskData;

  const WorkerPaymentScreen({
    super.key,
    required this.taskData,
  });

  @override
  ConsumerState<WorkerPaymentScreen> createState() => _WorkerPaymentScreenState();
}

class _WorkerPaymentScreenState extends ConsumerState<WorkerPaymentScreen> with SingleTickerProviderStateMixin {
  static const primaryColor = Color(0xFF2029C5);
  static const cashColor = Color(0xFF10B981);
  static const upiColor = Color(0xFF6C63FF);
  
  bool? _isUpi; // null for none selected, false for Cash, true for UPI
  double _dragPosition = 0.5; // Start at 0.5 (middle)
  bool _isProcessing = false;

  late final AnimationController _animationController;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 0.5, // Start controller at 0.5
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {
          _dragPosition = _slideAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _togglePaymentMethod(bool upi) {
    if (upi == _isUpi) return;
    setState(() {
      _isUpi = upi;
    });
    if (upi) {
      _animationController.animateTo(1.0);
    } else {
      _animationController.animateTo(0.0);
    }
  }

  Future<void> _processPaymentCollection() async {
    if (_isUpi == null) return;
    setState(() => _isProcessing = true);
    try {
      final String? bookingId = widget.taskData['id'] ?? widget.taskData['bookingId'];
      if (bookingId == null || bookingId.isEmpty) {
        throw 'Booking ID is missing';
      }

      final String selectedMethod = _isUpi! ? 'UPI' : 'Cash';

      // Update Booking in Firestore
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'paymentStatus': 'Paid',
        'paymentMethod': selectedMethod,
        'status': 'Pending Verification',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'paymentCollectedAt': FieldValue.serverTimestamp(),
      });

      // Show success bottom sheet or dialog
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text('$selectedMethod Payment Collected!'),
          description: const Text('The task has been marked as Pending Verification.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
        _showSuccessDialog(selectedMethod);
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error Collecting Payment'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cashColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: cashColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Confirmed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A payment of ₹${widget.taskData['totalPrice'] ?? '0'} has been successfully collected via $method.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Booking ID: #${widget.taskData['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A'}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                // Pop dialog, pop payment screen, and return success flag
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context, true); // Pop payment screen back to task list/details
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'GO TO DASHBOARD',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String totalPrice = widget.taskData['totalPrice']?.toString() ?? '0';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '100% Secure',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Choose Payment Method',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Swipe or select how you\'d like to collect payment',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              
              // Total Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$totalPrice',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              
              // Custom Sliding Toggle Selector
              _buildSliderToggle(),
              
              const SizedBox(height: 28),
              
              // Content Box (Placeholder, Cash details, or UPI QR + details)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isUpi == null
                    ? _buildPlaceholderBox()
                    : _isUpi == false
                        ? _buildCashBox()
                        : _buildUpiBox(),
              ),
              
              const SizedBox(height: 24),
              
              // Payment Collected Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isUpi == null || _isProcessing) ? null : _processPaymentCollection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUpi == true ? upiColor : (_isUpi == false ? cashColor : Colors.grey.shade300),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _isUpi == null ? 0 : 4,
                    shadowColor: _isUpi == null 
                        ? Colors.transparent 
                        : (_isUpi == true ? upiColor : cashColor).withOpacity(0.4),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _isUpi == null ? 'SELECT METHOD TO COLLECT' : 'Payment Collected'.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderToggle() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        const double trackHeight = 84.0;
        const double thumbSize = 72.0;
        final double maxSlide = trackWidth - thumbSize - 12.0; // 6px padding on each side

        // Calculate thumb horizontal position
        final double thumbPosition = _dragPosition * maxSlide;

        return Container(
          width: trackWidth,
          height: trackHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Left text/icon placeholder
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                width: (trackWidth - thumbSize) / 2 - 12,
                child: GestureDetector(
                  onTap: () => _togglePaymentMethod(false),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cashColor.withOpacity(_isUpi == false ? 0.15 : 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.payments_rounded,
                          color: _isUpi == false ? cashColor : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CASH',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isUpi == false ? cashColor : Colors.grey,
                            ),
                          ),
                          const Text(
                            'Pay at venue',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Right text/icon placeholder
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                width: (trackWidth - thumbSize) / 2 - 12,
                child: GestureDetector(
                  onTap: () => _togglePaymentMethod(true),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: upiColor.withOpacity(_isUpi == true ? 0.15 : 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: _isUpi == true ? upiColor : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UPI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _isUpi == true ? upiColor : Colors.grey,
                            ),
                          ),
                          const Text(
                            'Pay online',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Left side background color slide overlay
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: thumbPosition + (thumbSize / 2),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(38)),
                    gradient: LinearGradient(
                      colors: [
                        cashColor.withOpacity(0.2),
                        cashColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ),

              // Right side background color slide overlay
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                left: thumbPosition + (thumbSize / 2),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(38)),
                    gradient: LinearGradient(
                      colors: [
                        upiColor.withOpacity(0.05),
                        upiColor.withOpacity(0.2),
                      ],
                    ),
                  ),
                ),
              ),

              // Sliding Thumb
              Positioned(
                left: thumbPosition,
                top: (trackHeight - thumbSize - 3) / 2, // Center vertically
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition += details.delta.dx / maxSlide;
                      _dragPosition = _dragPosition.clamp(0.0, 1.0);
                      
                      // Dynamically set selection if dragged far enough
                      if (_dragPosition < 0.35) {
                        _isUpi = false;
                      } else if (_dragPosition > 0.65) {
                        _isUpi = true;
                      }
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition < 0.35) {
                      _togglePaymentMethod(false);
                    } else if (_dragPosition > 0.65) {
                      _togglePaymentMethod(true);
                    } else {
                      // Snap back to middle
                      setState(() {
                        _isUpi = null;
                      });
                      _animationController.animateTo(0.5);
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isUpi == true ? upiColor : (_isUpi == false ? cashColor : Colors.grey)).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: _isUpi == true ? upiColor : (_isUpi == false ? cashColor : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderBox() {
    return Container(
      key: const ValueKey('placeholder'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_left_alt_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'Select Payment Method',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Swipe or tap the slider above to choose between Cash or UPI payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCashBox() {
    return Container(
      key: const ValueKey('cash'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cashColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.money_rounded, color: cashColor, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cash Payment Selected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),
          
          _buildDetailRow('Service Title', widget.taskData['title'] ?? 'Car Washing Service'),
          _buildDetailRow('Booking ID', '#${widget.taskData['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A'}'),
          _buildDetailRow('Customer Name', widget.taskData['userName'] ?? 'Customer'),
          _buildDetailRow('Date & Time', _formatTaskDate()),
          _buildDetailRow('Payment Mode', 'CASH (Collect at venue)', valueColor: cashColor),
        ],
      ),
    );
  }

  Widget _buildUpiBox() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('payment_settings').doc('config').get(),
      builder: (context, snapshot) {
        String? qrImageUrl;
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          qrImageUrl = data?['upiQrUrl'] as String?;
        }

        return Container(
          key: const ValueKey('upi'),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: upiColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_rounded, color: upiColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'UPI Payment Selected',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Custom Drawn QR Code Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: qrImageUrl != null && qrImageUrl.isNotEmpty
                      ? Image.network(
                          qrImageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(upiColor),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return CustomPaint(
                              painter: QrCodePainter(
                                bookingId: widget.taskData['id'] ?? 'DUMMY_ID',
                                accentColor: upiColor,
                              ),
                            );
                          },
                        )
                      : (snapshot.connectionState == ConnectionState.waiting
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(upiColor),
                              ),
                            )
                          : CustomPaint(
                              painter: QrCodePainter(
                                bookingId: widget.taskData['id'] ?? 'DUMMY_ID',
                                accentColor: upiColor,
                              ),
                            )),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan QR code to pay',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 20),
              
              _buildDetailRow('Service Title', widget.taskData['title'] ?? 'Car Washing Service', alignLeft: true),
              _buildDetailRow('Booking ID', '#${widget.taskData['id']?.toString().substring(0, 8).toUpperCase() ?? 'N/A'}', alignLeft: true),
              _buildDetailRow('Customer Name', widget.taskData['userName'] ?? 'Customer', alignLeft: true),
              _buildDetailRow('Date & Time', _formatTaskDate(), alignLeft: true),
              _buildDetailRow('Payment Mode', 'UPI (Collect Online)', valueColor: upiColor, alignLeft: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool alignLeft = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTaskDate() {
    final dynamic timestamp = widget.taskData['updatedAt'] ?? widget.taskData['createdAt'];
    if (timestamp is Timestamp) {
      return DateFormat('EEE, d MMMM - hh:mm a').format(timestamp.toDate());
    }
    return widget.taskData['time']?.toString() ?? 'Date not specified';
  }
}

class QrCodePainter extends CustomPainter {
  final String bookingId;
  final Color accentColor;

  QrCodePainter({required this.bookingId, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint blackPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
      
    final Paint accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
      
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw the 3 finder pattern anchors (corners)
    // 1. Top Left
    _drawFinderPattern(canvas, const Offset(0, 0), 40, blackPaint, whitePaint);
    // 2. Top Right
    _drawFinderPattern(canvas, Offset(size.width - 40, 0), 40, blackPaint, whitePaint);
    // 3. Bottom Left
    _drawFinderPattern(canvas, Offset(0, size.height - 40), 40, blackPaint, whitePaint);

    // Draw deterministic mock QR blocks based on booking ID hash
    final int hash = bookingId.hashCode;
    final int gridCount = 21; // 21x21 QR Grid
    final double blockSize = size.width / gridCount;

    for (int r = 0; r < gridCount; r++) {
      for (int c = 0; c < gridCount; c++) {
        // Skip corner finder pattern areas
        if ((r < 7 && c < 7) || (r < 7 && c >= gridCount - 7) || (r >= gridCount - 7 && c < 7)) {
          continue;
        }

        // Deterministic pseudo-random generation of blocks using row, col and hash
        final int seed = hash ^ (r * 113) ^ (c * 23);
        if (seed % 3 == 0) {
          final Rect block = Rect.fromLTWH(c * blockSize, r * blockSize, blockSize + 0.5, blockSize + 0.5);
          
          // Style center blocks or random blocks with accent color
          if (r > 8 && r < 12 && c > 8 && c < 12) {
            canvas.drawRect(block, accentPaint);
          } else {
            canvas.drawRect(block, blackPaint);
          }
        }
      }
    }

    // Draw center logo area
    final double centerSize = 36.0;
    final double centerLeft = (size.width - centerSize) / 2;
    final double centerTop = (size.height - centerSize) / 2;
    final RRect centerBackground = RRect.fromRectAndRadius(
      Rect.fromLTWH(centerLeft, centerTop, centerSize, centerSize),
      const Radius.circular(8),
    );
    canvas.drawRRect(centerBackground, whitePaint);
    
    final Paint borderPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(centerBackground, borderPaint);

    // Draw Rupee symbol in center of QR
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: accentColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerLeft + (centerSize - textPainter.width) / 2,
        centerTop + (centerSize - textPainter.height) / 2,
      ),
    );
  }

  void _drawFinderPattern(Canvas canvas, Offset offset, double size, Paint blackPaint, Paint whitePaint) {
    // Outer black square
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), blackPaint);
    // Inner white square
    canvas.drawRect(Rect.fromLTWH(offset.dx + size / 7, offset.dy + size / 7, size * 5 / 7, size * 5 / 7), whitePaint);
    // Inner black center core
    canvas.drawRect(Rect.fromLTWH(offset.dx + size * 2 / 7, offset.dy + size * 2 / 7, size * 3 / 7, size * 3 / 7), blackPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
