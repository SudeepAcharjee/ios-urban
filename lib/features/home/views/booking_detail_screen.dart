import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import 'write_review_screen.dart';
import 'categories_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailScreen({
    super.key,
    required this.bookingData,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  static const primaryColor = Color(0xFF2029C5);
  late Map<String, dynamic> _bookingData;
  bool _isCleaningExpired = false;

  bool _hasValidBeforeServicePhotos(Map<String, dynamic> data) {
    final rawUrls = data['beforeServiceProofUrls'];
    if (rawUrls is! List || rawUrls.isEmpty) return false;

    final expiry = data['proofExpiresAt'] ?? data['proofExpiryDate'];
    if (expiry is Timestamp) {
      if (DateTime.now().isAfter(expiry.toDate())) {
        _cleanupExpiredPhotos();
        return false;
      }
    }
    return true;
  }

  void _cleanupExpiredPhotos() {
    final bId = widget.bookingData['id']?.toString() ?? widget.bookingData['bookingId']?.toString();
    if (bId == null || bId.isEmpty || _isCleaningExpired) return;
    _isCleaningExpired = true;
    FirebaseFirestore.instance.collection('bookings').doc(bId).update({
      'beforeServiceProofUrls': FieldValue.delete(),
      'proofExpiresAt': FieldValue.delete(),
      'proofExpiryDate': FieldValue.delete(),
      'beforeServiceTimestamp': FieldValue.delete(),
    }).catchError((e) => debugPrint('Error cleaning expired proof photos: $e'));
  }

  @override
  void initState() {
    super.initState();
    _bookingData = widget.bookingData;
  }

  Future<void> _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Contact phone number is not available.'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Could not open phone dialer.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _openInGoogleMaps({dynamic lat, dynamic lng, String? address}) async {
    double? numLat = lat is num ? lat.toDouble() : double.tryParse(lat?.toString() ?? '');
    double? numLng = lng is num ? lng.toDouble() : double.tryParse(lng?.toString() ?? '');

    Uri mapUri;
    if (numLat != null && numLng != null && numLat != 0 && numLng != 0) {
      mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$numLat,$numLng');
    } else if (address != null && address.trim().isNotEmpty) {
      mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}');
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Location coordinates not available'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(mapUri);
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Could not open Google Maps'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _cancelBooking(BuildContext context, String bookingId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Cancel Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this booking?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': 'Cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flatColored,
            title: const Text('Cancelled Successfully'),
            description: const Text('Your booking has been cancelled.'),
            alignment: Alignment.topCenter,
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      } catch (e) {
        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Error cancelling booking'),
            description: Text(e.toString()),
          );
        }
      }
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      return DateFormat('d MMM yyyy, hh:mm a').format(ts.toDate());
    }
    if (ts is String && ts.isNotEmpty) {
      return ts;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String bookingId = (_bookingData['bookingId'] ?? _bookingData['id'] ?? '').toString();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: bookingId.isNotEmpty
          ? FirebaseFirestore.instance.collection('bookings').doc(bookingId).snapshots()
          : null,
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data?.data() != null
            ? {
                ..._bookingData,
                ...snapshot.data!.data()!,
                'id': bookingId,
              }
            : _bookingData;

        final String title = (data['title'] ?? data['serviceName'] ?? 'Service').toString();
        final num rawPrice = (data['totalPrice'] is num)
            ? data['totalPrice']
            : (data['price'] is num)
                ? data['price']
                : num.tryParse(data['totalPrice']?.toString() ?? '') ??
                    num.tryParse(data['price']?.toString() ?? '') ?? 0;
        final String price = rawPrice.toString();
        final String status = (data['status'] ?? 'Pending').toString();
        final rawDate = data['date'] ?? data['bookingDate'];
        final String timeSlot = (data['time'] ?? data['timeSlot'] ?? '').toString();
        final String vehicleModel = (data['carModel'] ?? data['vehicleName'] ?? data['vehicle'] ?? '').toString();
        final String vehicleNumber = (data['vehicleNumber'] ?? data['carNumber'] ?? '').toString();
        final String serviceImage = (data['imagePath'] ?? data['serviceImage'] ?? data['imageUrl'] ?? '').toString();
        final String category = (data['category'] ?? data['categoryId'] ?? 'Workshop').toString();

        final String shopId = (data['shopId'] ?? data['ownerId'] ?? '').toString();
        final String serviceId = (data['serviceId'] ?? '').toString();
        final bool isShopBooking = shopId.isNotEmpty || data['shopName'] != null;

        final rawAddress = data['address'];
        String userAddress = '';
        if (rawAddress is Map) {
          userAddress = (rawAddress['address'] ?? rawAddress['doorstepAddress'] ?? rawAddress['formattedAddress'] ?? '').toString();
        } else if (rawAddress is String) {
          userAddress = rawAddress;
        }

        String dateStr = '';
        if (rawDate != null) {
          if (rawDate is Timestamp) {
            dateStr = DateFormat('d MMM, yyyy').format(rawDate.toDate());
          } else {
            dateStr = rawDate.toString();
          }
        }

        final stLower = status.toLowerCase();
        final isCancelled = stLower == 'cancelled';
        final isCompleted = stLower == 'completed' || stLower == 'job completed';
        final isInProgress = stLower == 'in progress' || stLower == 'in-progress';
        final isConfirmed = stLower == 'confirmed' || stLower == 'assigned';
        final isPending = stLower == 'pending';

        Color statusColor;
        Color statusBg;
        if (isPending) {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFEF3C7);
        } else if (isConfirmed) {
          statusColor = const Color(0xFF2563EB);
          statusBg = const Color(0xFFDBEAFE);
        } else if (isInProgress) {
          statusColor = const Color(0xFF7C3AED);
          statusBg = const Color(0xFFEDE9FE);
        } else if (isCompleted) {
          statusColor = const Color(0xFF059669);
          statusBg = const Color(0xFFD1FAE5);
        } else {
          statusColor = Colors.red.shade700;
          statusBg = Colors.red.shade50;
        }

        // Timestamps for progress tracking
        final placedTime = _formatTimestamp(data['createdAt']);
        final confirmedTime = _formatTimestamp(data['confirmedAt'] ?? (isConfirmed || isInProgress || isCompleted ? data['statusUpdatedAt'] : null));
        final inProgressTime = _formatTimestamp(data['inProgressAt'] ?? (isInProgress || isCompleted ? data['statusUpdatedAt'] : null));
        final completedTime = _formatTimestamp(data['completedAt'] ?? (isCompleted ? data['statusUpdatedAt'] : null));
        final cancelledTime = _formatTimestamp(data['cancelledAt'] ?? (isCancelled ? data['statusUpdatedAt'] : null));

        final idDisplay = bookingId.length > 8 ? bookingId.substring(bookingId.length - 8) : bookingId;

        final bool isAccepted = isConfirmed || isInProgress || isCompleted;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ID: #$idDisplay',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 36.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. SHOP / WORKSHOP DETAILS CARD (Only shown after booking is accepted)
                  if (isAccepted) ...[
                    if (isShopBooking) ...[
                      _buildShopDetailsCard(
                        context: context,
                        shopId: shopId,
                        serviceId: serviceId,
                        bookingId: bookingId,
                        fallbackShopName: (data['shopName'] ?? 'Workshop').toString(),
                        serviceTitle: title,
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      _buildWorkerDetailsCard(
                        context: context,
                        data: data,
                        bookingId: bookingId,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // 2. FLIPKART / AMAZON STYLE TRACK BOOKING PROGRESS STEPPER
                  _buildTrackBookingProgressCard(
                    status: status,
                    isPending: isPending,
                    isConfirmed: isConfirmed,
                    isInProgress: isInProgress,
                    isCompleted: isCompleted,
                    isCancelled: isCancelled,
                    placedTime: placedTime,
                    confirmedTime: confirmedTime,
                    inProgressTime: inProgressTime,
                    completedTime: completedTime,
                    cancelledTime: cancelledTime,
                    isShopBooking: isShopBooking,
                  ),
                  const SizedBox(height: 16),

                  // 3. BEFORE SERVICE VEHICLE INSPECTION PHOTOS (7-Day Auto Deletion)
                  if (_hasValidBeforeServicePhotos(data)) ...[
                    _buildBeforeServicePhotosCard(context, data),
                    const SizedBox(height: 16),
                  ],

                  // 4. SHOP LOCATION & GOOGLE MAPS CARD (Only shown for shop bookings after booking is accepted)
                  if (isShopBooking && isAccepted) ...[
                    _buildShopLocationMapCard(
                      context: context,
                      shopId: shopId,
                      serviceId: serviceId,
                      fallbackShopName: (data['shopName'] ?? 'Workshop').toString(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. SERVICE & VEHICLE SUMMARY CARD
                  _buildServiceSummaryCard(
                    title: title,
                    category: category,
                    vehicleModel: vehicleModel,
                    vehicleNumber: vehicleNumber,
                    dateStr: dateStr,
                    timeSlot: timeSlot,
                    price: price,
                    serviceImage: serviceImage,
                    userAddress: userAddress,
                    isShopBooking: isShopBooking,
                  ),
                  const SizedBox(height: 16),

                  // 5. PAYMENT SUMMARY CARD
                  _buildPaymentSummaryCard(
                    price: price,
                    paymentMethod: (data['paymentMethod'] ?? 'Cash').toString(),
                    paymentStatus: (data['paymentStatus'] ?? (isCompleted ? 'Paid' : 'Pending')).toString(),
                    razorpayPaymentId: data['razorpayPaymentId']?.toString(),
                  ),
                  const SizedBox(height: 20),

                  // 6. BOTTOM CONTEXTUAL ACTIONS
                  _buildBottomActions(
                    context: context,
                    bookingId: bookingId,
                    data: data,
                    isPending: isPending,
                    isConfirmed: isConfirmed,
                    isInProgress: isInProgress,
                    isCompleted: isCompleted,
                    isCancelled: isCancelled,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 1. SHOP DETAILS CARD (Shop Name, Photo, Phone, Address, Call & Chat Buttons)
  // --------------------------------------------------------------------------
  Widget _buildShopDetailsCard({
    required BuildContext context,
    required String shopId,
    required String serviceId,
    required String bookingId,
    required String fallbackShopName,
    required String serviceTitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Workshop Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: shopId.isNotEmpty
                ? FirebaseFirestore.instance.collection('shops').doc(shopId).snapshots()
                : null,
            builder: (context, shopSnap) {
              final shopData = shopSnap.data?.data() ?? {};

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: (shopData.isEmpty && serviceId.isNotEmpty)
                    ? FirebaseFirestore.instance.collection('services').doc(serviceId).snapshots()
                    : null,
                builder: (context, serviceSnap) {
                  final sData = serviceSnap.data?.data() ?? {};

                  final String shopName = (shopData['shopName'] ??
                          shopData['businessName'] ??
                          sData['shopName'] ??
                          sData['businessName'] ??
                          fallbackShopName)
                      .toString();

                  final String phone = (shopData['phone'] ??
                          shopData['contactPhone'] ??
                          shopData['phoneNumber'] ??
                          '')
                      .toString();

                  final String serviceType = (shopData['serviceType'] ??
                          sData['category'] ??
                          'Car & Bike Servicing')
                      .toString();

                  final String shopAddress = (shopData['address'] ??
                          shopData['shopAddress'] ??
                          sData['address'] ??
                          'Location available in map')
                      .toString();

                  final String? shopImage = (shopData['shopImage'] ??
                      shopData['bannerImage'] ??
                      shopData['profilePic'] ??
                      shopData['imageUrl'] ??
                      sData['image'])?.toString();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            backgroundImage: (shopImage != null && shopImage.isNotEmpty)
                                ? NetworkImage(shopImage)
                                : null,
                            child: (shopImage == null || shopImage.isEmpty)
                                ? Text(
                                    shopName.isNotEmpty ? shopName[0].toUpperCase() : 'W',
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  serviceType,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (shopAddress.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  shopAddress,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // CALL & CHAT ACTION BUTTONS
                      Row(
                        children: [
                          // CALL WORKSHOP BUTTON
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: phone.isNotEmpty ? () => _callPhone(phone) : null,
                              icon: const Icon(Icons.call_rounded, size: 18),
                              label: const Text(
                                'Call Workshop',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // CHAT BUTTON
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final String actualShopId = shopId.isNotEmpty
                                    ? shopId
                                    : (sData['ownerId'] ?? sData['shopId'] ?? '').toString();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      providerName: shopName,
                                      providerRole: 'Workshop',
                                      bookingId: 'bookings/$bookingId',
                                      imageUrl: shopImage,
                                      recipientId: actualShopId.isNotEmpty ? actualShopId : null,
                                      recipientRole: 'shop',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: const Text(
                                'Chat',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // WORKER DETAILS CARD (Fallback for Doorstep / Worker Service)
  Widget _buildWorkerDetailsCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String bookingId,
  }) {
    final String workerId = (data['workerId'] ?? '').toString();
    final String workerName = (data['workerName'] ?? 'Service Professional').toString();
    final String workerRole = (data['workerRole'] ?? 'Service Provider').toString();
    final String? workerImage = data['workerImage']?.toString();
    final String? otp = data['otp']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.engineering_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Service Professional',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: workerId.isNotEmpty
                ? FirebaseFirestore.instance.collection('workers').doc(workerId).snapshots()
                : null,
            builder: (context, snapshot) {
              String displayName = workerName;
              String? displayImage = workerImage;
              String displayPhone = (data['workerPhone'] ?? '').toString();

              if (snapshot.hasData && snapshot.data?.data() != null) {
                final wData = snapshot.data!.data()!;
                displayName = (wData['name'] ?? wData['fullName'] ?? workerName).toString();
                displayImage = (wData['profilePic'] ?? wData['imageUrl'] ?? workerImage)?.toString();
                displayPhone = (wData['phone'] ?? wData['phoneNumber'] ?? displayPhone).toString();
              }

              return Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        backgroundImage: (displayImage != null && displayImage.isNotEmpty)
                            ? NetworkImage(displayImage)
                            : null,
                        child: (displayImage == null || displayImage.isEmpty)
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              workerRole,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (displayPhone.isNotEmpty) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _callPhone(displayPhone),
                            icon: const Icon(Icons.call_rounded, size: 18),
                            label: const Text('Call', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  providerName: displayName,
                                  providerRole: workerRole,
                                  bookingId: 'bookings/$bookingId',
                                  imageUrl: displayImage,
                                  recipientId: workerId.isNotEmpty ? workerId : null,
                                  recipientRole: 'worker',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          if (otp != null && otp.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.security_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Service Start OTP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    otp,
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. FLIPKART / AMAZON STYLE STEP PROGRESS TRACKER
  // --------------------------------------------------------------------------
  Widget _buildTrackBookingProgressCard({
    required String status,
    required bool isPending,
    required bool isConfirmed,
    required bool isInProgress,
    required bool isCompleted,
    required bool isCancelled,
    required String placedTime,
    required String confirmedTime,
    required String inProgressTime,
    required String completedTime,
    required String cancelledTime,
    required bool isShopBooking,
  }) {
    final bool step1Active = true;
    final bool step1Done = isConfirmed || isInProgress || isCompleted;

    final bool step2Active = isConfirmed || isInProgress || isCompleted;
    final bool step2Done = isInProgress || isCompleted;

    final bool step3Active = isInProgress || isCompleted;
    final bool step3Done = isCompleted;

    final bool step4Active = isCompleted;
    final bool step4Done = isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Track Booking Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),

          if (isCancelled) ...[
            _buildTrackerStep(
              title: 'Booking Placed',
              description: 'You placed the service request',
              time: placedTime,
              isDone: true,
              isActive: true,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),
            _buildTrackerStep(
              title: 'Booking Cancelled',
              description: 'This booking request was cancelled',
              time: cancelledTime.isNotEmpty ? cancelledTime : 'Cancelled',
              isDone: true,
              isActive: true,
              isLast: true,
              activeColor: Colors.red,
              nodeIcon: Icons.close_rounded,
            ),
          ] else ...[
            // STEP 1: BOOKING PLACED
            _buildTrackerStep(
              title: 'Booking Placed',
              description: 'Customer placed the service request',
              time: placedTime,
              isDone: step1Done,
              isActive: step1Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 2: BOOKING CONFIRMED / ACCEPTED
            _buildTrackerStep(
              title: 'Booking Confirmed',
              description: step2Active
                  ? (isShopBooking ? 'Workshop accepted this booking' : 'Service provider confirmed booking')
                  : (isShopBooking ? 'Awaiting acceptance from workshop' : 'Awaiting confirmation'),
              time: confirmedTime,
              isDone: step2Done,
              isActive: step2Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 3: SERVICE IN PROGRESS
            _buildTrackerStep(
              title: 'Service In Progress',
              description: step3Active
                  ? (isShopBooking ? 'Vehicle is actively being serviced' : 'Professional is servicing your vehicle')
                  : 'Waiting for service to begin',
              time: inProgressTime,
              isDone: step3Done,
              isActive: step3Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 4: SERVICE COMPLETED
            _buildTrackerStep(
              title: 'Service Completed',
              description: step4Active
                  ? 'Service completed successfully'
                  : 'Service will be marked done upon completion',
              time: completedTime,
              isDone: step4Done,
              isActive: step4Active,
              isLast: true,
              activeColor: const Color(0xFF059669),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackerStep({
    required String title,
    required String description,
    required String time,
    required bool isDone,
    required bool isActive,
    required bool isLast,
    required Color activeColor,
    IconData? nodeIcon,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left tracker node + vertical connecting line
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? activeColor
                      : (isActive ? activeColor.withOpacity(0.15) : Colors.grey.shade100),
                  border: Border.all(
                    color: isDone || isActive ? activeColor : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    nodeIcon ?? (isDone ? Icons.check_rounded : (isActive ? Icons.radio_button_checked_rounded : Icons.circle_outlined)),
                    size: isDone || nodeIcon != null ? 14 : 10,
                    color: isDone
                        ? Colors.white
                        : (isActive ? activeColor : Colors.grey.shade400),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone ? activeColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Right text details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive || isDone ? const Color(0xFF0F172A) : Colors.grey.shade500,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive || isDone ? const Color(0xFF475569) : Colors.grey.shade400,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 3. SHOP LOCATION & GOOGLE MAPS CARD (With Lat & Lng support)
  // --------------------------------------------------------------------------
  Widget _buildShopLocationMapCard({
    required BuildContext context,
    required String shopId,
    required String serviceId,
    required String fallbackShopName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Workshop Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: shopId.isNotEmpty
                ? FirebaseFirestore.instance.collection('shops').doc(shopId).snapshots()
                : null,
            builder: (context, shopSnap) {
              final shopData = shopSnap.data?.data() ?? {};

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: (shopData.isEmpty && serviceId.isNotEmpty)
                    ? FirebaseFirestore.instance.collection('services').doc(serviceId).snapshots()
                    : null,
                builder: (context, serviceSnap) {
                  final sData = serviceSnap.data?.data() ?? {};

                  final String shopName = (shopData['shopName'] ??
                          shopData['businessName'] ??
                          sData['shopName'] ??
                          sData['businessName'] ??
                          fallbackShopName)
                      .toString();

                  final String address = (shopData['address'] ??
                          shopData['shopAddress'] ??
                          sData['address'] ??
                          'Address not specified')
                      .toString();

                  final dynamic rawLat = shopData['latitude'] ?? shopData['lat'] ?? sData['latitude'] ?? sData['lat'];
                  final dynamic rawLng = shopData['longitude'] ?? shopData['lng'] ?? sData['longitude'] ?? sData['lng'];

                  final double? lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '');
                  final double? lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map Graphic Container Preview
                      Container(
                        width: double.infinity,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Background grid lines design
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _MapGridPainter(),
                              ),
                            ),

                            // Center Pin Marker & Tooltip
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storefront_rounded, size: 12, color: primaryColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          shopName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 32,
                                    color: Color(0xFFEF4444),
                                  ),
                                ],
                              ),
                            ),

                            // Coordinates badge top left
                            if (lat != null && lng != null)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location text details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 18, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // VIEW IN GOOGLE MAPS BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openInGoogleMaps(lat: lat, lng: lng, address: address),
                          icon: const Icon(Icons.directions_outlined, size: 18),
                          label: const Text(
                            'View in Google Maps',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. SERVICE & VEHICLE SUMMARY CARD
  // --------------------------------------------------------------------------
  Widget _buildServiceSummaryCard({
    required String title,
    required String category,
    required String vehicleModel,
    required String vehicleNumber,
    required String dateStr,
    required String timeSlot,
    required String price,
    required String serviceImage,
    required String userAddress,
    required bool isShopBooking,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Service & Vehicle Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade100,
                  child: serviceImage.isNotEmpty
                      ? (serviceImage.startsWith('http')
                          ? Image.network(
                              serviceImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.car_repair_rounded, color: primaryColor, size: 36),
                            )
                          : Image.asset(
                              serviceImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.car_repair_rounded, color: primaryColor, size: 36),
                            ))
                      : const Icon(Icons.car_repair_rounded, color: primaryColor, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.isNotEmpty ? category : 'Workshop Service',
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Vehicle info
          if (vehicleModel.isNotEmpty || vehicleNumber.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      if (vehicleModel.isNotEmpty) vehicleModel,
                      if (vehicleNumber.isNotEmpty) '($vehicleNumber)',
                    ].join(' '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Schedule date and time
          if (dateStr.isNotEmpty || timeSlot.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [if (dateStr.isNotEmpty) dateStr, if (timeSlot.isNotEmpty) timeSlot].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // User address (for doorstep bookings)
          if (!isShopBooking && userAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. PAYMENT SUMMARY CARD
  // --------------------------------------------------------------------------
  Widget _buildPaymentSummaryCard({
    required String price,
    required String paymentMethod,
    required String paymentStatus,
    String? razorpayPaymentId,
  }) {
    final isPaid = paymentStatus.toLowerCase() == 'paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          _buildPaymentRow('Payment Method', paymentMethod),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Status',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green.shade800 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (razorpayPaymentId != null && razorpayPaymentId.isNotEmpty) ...[
            _buildPaymentRow('Payment ID', razorpayPaymentId),
          ],

          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 6. BOTTOM CONTEXTUAL ACTIONS (Review, Cancel, Book Again)
  // --------------------------------------------------------------------------
  Widget _buildBottomActions({
    required BuildContext context,
    required String bookingId,
    required Map<String, dynamic> data,
    required bool isPending,
    required bool isConfirmed,
    required bool isInProgress,
    required bool isCompleted,
    required bool isCancelled,
  }) {
    return Row(
      children: [
        if (isCompleted) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WriteReviewScreen(bookingData: data)),
                );
              },
              icon: const Icon(Icons.star_rate_rounded, size: 18),
              label: const Text('Write a Review', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        if (isPending) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancelBooking(context, bookingId),
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
              label: const Text('Cancel Booking', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],

        if (isCompleted || isCancelled) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
              },
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Book Again', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // BEFORE-SERVICE VEHICLE INSPECTION PHOTOS CARD WITH 7-DAY RETENTION
  Widget _buildBeforeServicePhotosCard(BuildContext context, Map<String, dynamic> data) {
    final List<dynamic> rawUrls = data['beforeServiceProofUrls'] ?? [];
    final List<String> urls = rawUrls.map((e) => e.toString()).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final expiry = data['proofExpiresAt'] ?? data['proofExpiryDate'];
    int daysLeft = 7;
    String expiryFormatted = '';
    if (expiry is Timestamp) {
      final expDate = expiry.toDate();
      daysLeft = expDate.difference(DateTime.now()).inDays + 1;
      if (daysLeft < 0) daysLeft = 0;
      expiryFormatted = DateFormat('d MMM, hh:mm a').format(expDate);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Before-Service Inspection',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Photos captured by workshop',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              // Auto-delete badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Text(
                      daysLeft <= 0 ? 'Deleting soon' : 'Auto-deletes in $daysLeft d',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Thumbnails row
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                final imgUrl = urls[index];
                return GestureDetector(
                  onTap: () => _showImagePreviewDialog(context, imgUrl, index, urls),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          image: DecorationImage(
                            image: NetworkImage(imgUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  expiryFormatted.isNotEmpty
                      ? 'Retained until $expiryFormatted for verification before auto-deletion.'
                      : 'Auto-deletes after 7 days for verification & security.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FULLSCREEN IMAGE VIEWER WITH PINCH ZOOM
  void _showImagePreviewDialog(BuildContext context, String currentUrl, int initialIndex, List<String> allUrls) {
    showDialog(
      context: context,
      builder: (ctx) {
        int activeIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.black.withOpacity(0.92),
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: allUrls.length,
                    onPageChanged: (i) => setDialogState(() => activeIndex = i),
                    itemBuilder: (pageCtx, idx) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            allUrls[idx],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: MediaQuery.of(ctx).padding.top + 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${activeIndex + 1} / ${allUrls.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --------------------------------------------------------------------------
// Custom painter to draw subtle stylish grid lines on map preview
// --------------------------------------------------------------------------
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // A subtle curved road line
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.9,
        size.width * 0.6,
        size.height * 0.3,
        size.width,
        size.height * 0.5,
      );

    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
