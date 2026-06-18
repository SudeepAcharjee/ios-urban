import 'package:car_washing_service_app/features/home/views/chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
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
  late Map<String, dynamic> _bookingData;

  @override
  void initState() {
    super.initState();
    _bookingData = widget.bookingData;
  }

  Future<void> _refreshBooking() async {
    try {
      final bookingId = _bookingData['bookingId'] ?? _bookingData['id'];
      if (bookingId != null) {
        final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _bookingData = doc.data()!;
            _bookingData['id'] = doc.id;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing booking: $e');
    }
  }

  Future<void> _cancelBooking(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final bookingId = _bookingData['bookingId'] ?? _bookingData['id'];
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .update({'status': 'Cancelled', 'updatedAt': FieldValue.serverTimestamp()});
        
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
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling booking: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2029C5);
    
    final String title = _bookingData['title'] ?? 'Service';
    final int price = (_bookingData['totalPrice'] as num? ?? _bookingData['price'] as num? ?? 0).toInt();
    final String status = _bookingData['status'] ?? 'Pending';
    final currentStatus = status.toUpperCase();

    // Logic for timeline activation
    bool isPendingActive = true;
    bool isConfirmedActive = currentStatus == 'CONFIRMED' || currentStatus == 'IN PROGRESS' || currentStatus == 'COMPLETED' || currentStatus == 'JOB COMPLETED';
    bool isInProgressActive = currentStatus == 'IN PROGRESS' || currentStatus == 'COMPLETED' || currentStatus == 'JOB COMPLETED';
    bool isCompletedActive = currentStatus == 'COMPLETED' || currentStatus == 'JOB COMPLETED';
    bool isCancelled = currentStatus == 'CANCELLED';

    // Format timestamps for timeline
    String formatTimestamp(dynamic ts) {
      if (ts == null) return '';
      if (ts is Timestamp) {
        return DateFormat('d MMM at hh:mm a').format(ts.toDate());
      }
      return '';
    }

    final String statusUpdatedTime = formatTimestamp(_bookingData['statusUpdatedAt'] ?? _bookingData['updatedAt']);

    final String pendingTime = formatTimestamp(_bookingData['createdAt']);
    
    final String confirmedTime = _bookingData['confirmedAt'] != null 
        ? formatTimestamp(_bookingData['confirmedAt']) 
        : (currentStatus == 'CONFIRMED' ? statusUpdatedTime : (isConfirmedActive ? pendingTime : ''));
        
    final String inProgressTime = _bookingData['inProgressAt'] != null 
        ? formatTimestamp(_bookingData['inProgressAt']) 
        : (currentStatus == 'IN PROGRESS' ? statusUpdatedTime : (isInProgressActive ? (confirmedTime.isNotEmpty ? confirmedTime : pendingTime) : ''));
        
    final String completedTime = _bookingData['completedAt'] != null 
        ? formatTimestamp(_bookingData['completedAt']) 
        : ((currentStatus == 'COMPLETED' || currentStatus == 'JOB COMPLETED') ? statusUpdatedTime : (isCompletedActive ? (inProgressTime.isNotEmpty ? inProgressTime : pendingTime) : ''));
        
    final String cancelledTime = statusUpdatedTime;

    // Button states
    bool canBookAgain = isCompletedActive || isCancelled;

    // Provider / Worker details
    final String workerName = _bookingData['workerName'] ?? 'Sudeep';
    final String workerRole = _bookingData['workerRole'] ?? 'Service Provider';
    final String? workerImage = _bookingData['workerImage'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: primaryGreen,
        backgroundColor: Colors.white,
        onRefresh: _refreshBooking,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Card
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey.shade100,
                    child: _bookingData['imagePath'] != null
                        ? Image.network(
                            _bookingData['imagePath'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_car_wash, size: 50, color: primaryGreen),
                          )
                        : const Icon(Icons.local_car_wash, size: 50, color: primaryGreen),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 5),

                      const SizedBox(height: 5),
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // ⚡ Contextual Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WriteReviewScreen(bookingData: _bookingData)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: primaryGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Write a Review', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                
                if (currentStatus == 'PENDING' || currentStatus == 'CONFIRMED' || currentStatus == 'IN PROGRESS') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (currentStatus == 'CONFIRMED' || currentStatus == 'IN PROGRESS') {
                          toastification.show(
                            context: context,
                            type: ToastificationType.warning,
                            style: ToastificationStyle.flatColored,
                            title: const Text('Cancellation Restricted'),
                            description: const Text('Your booking has been started and cannot be cancelled.'),
                            alignment: Alignment.topCenter,
                            autoCloseDuration: const Duration(seconds: 4),
                          );
                        } else {
                          _cancelBooking(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: (currentStatus == 'CONFIRMED' || currentStatus == 'IN PROGRESS') ? Colors.grey : Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel Booking',
                        style: TextStyle(
                          color: (currentStatus == 'CONFIRMED' || currentStatus == 'IN PROGRESS') ? Colors.grey : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                if (canBookAgain) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Book Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 30),

            // About Service Provider (Only show if confirmed or completed)
            if (isConfirmedActive) ...[
              const Text(
                'About Service Provider',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: (_bookingData['workerId'] != null && _bookingData['workerId'].toString().isNotEmpty)
                          ? FirebaseFirestore.instance.collection('workers').doc(_bookingData['workerId']).snapshots()
                          : null,
                      builder: (context, snapshot) {
                        String? latestWorkerImage = workerImage;
                        String latestWorkerName = workerName;

                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                          final workerDoc = snapshot.data!.data() as Map<String, dynamic>?;
                          if (workerDoc != null) {
                            if (workerDoc['profilePic'] != null && workerDoc['profilePic'].toString().isNotEmpty) {
                              latestWorkerImage = workerDoc['profilePic'];
                            } else if (workerDoc['imageUrl'] != null && workerDoc['imageUrl'].toString().isNotEmpty) {
                              latestWorkerImage = workerDoc['imageUrl'];
                            }
                            if (workerDoc['name'] != null && workerDoc['name'].toString().isNotEmpty) {
                              latestWorkerName = workerDoc['name'];
                            } else if (workerDoc['fullName'] != null && workerDoc['fullName'].toString().isNotEmpty) {
                              latestWorkerName = workerDoc['fullName'];
                            }
                            if (workerDoc['phone'] != null && workerDoc['phone'].toString().isNotEmpty) {
                            }
                          }
                        }

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: latestWorkerImage != null && latestWorkerImage.isNotEmpty ? NetworkImage(latestWorkerImage) : null,
                              child: (latestWorkerImage == null || latestWorkerImage.isEmpty) ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(latestWorkerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(workerRole, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      providerName: latestWorkerName,
                                      providerRole: workerRole,
                                      bookingId: 'bookings/${_bookingData['bookingId'] ?? _bookingData['id'] ?? 'unknown'}',
                                      imageUrl: latestWorkerImage,
                                      recipientId: _bookingData['workerId'],
                                      recipientRole: 'worker',
                                    ),
                                  ),
                                );
                              },
                              child: _buildIconAction(Icons.chat_bubble_rounded, primaryGreen),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_bookingData['otp'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.security_outlined, size: 20, color: primaryGreen),
                          const SizedBox(width: 10),
                          const Text(
                            'Service OTP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: primaryGreen.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: primaryGreen.withOpacity(0.1)),
                            ),
                            child: Text(
                              _bookingData['otp'].toString(),
                              style: const TextStyle(
                                color: primaryGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Booking Status
            const Text(
              'Booking Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (isCancelled) ...[
              _buildTimelineItem(
                'Booking Cancelled',
                'This booking was cancelled.',
                cancelledTime,
                true,
                true,
                Colors.red,
              ),
            ] else ...[
              _buildTimelineItem(
                'Booking Pending',
                'We have received your booking and it is under review',
                pendingTime,
                isPendingActive,
                false,
                primaryGreen,
              ),
              _buildTimelineItem(
                'Booking Confirmed',
                currentStatus == 'PENDING' 
                    ? 'Awaiting confirmation from admin' 
                    : 'Service provider has accepted your booking',
                confirmedTime,
                isConfirmedActive,
                false,
                primaryGreen,
              ),
              _buildTimelineItem(
                'Service In Progress',
                currentStatus == 'CONFIRMED'
                    ? 'Waiting for service to start'
                    : 'Professional has started working on your service',
                inProgressTime,
                isInProgressActive,
                false,
                primaryGreen,
              ),
              _buildTimelineItem(
                'Service Completed',
                'Service Provider has completed his service',
                completedTime,
                isCompletedActive,
                true,
                primaryGreen,
              ),
            ],

            const SizedBox(height: 30),

            // Payment Summary
            const Text(
              'Payment Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildPaymentRow('Item Total', '₹${price + 10}', primaryGreen),
            _buildPaymentRow('Discount', '₹10', primaryGreen),
            _buildPaymentRow('Visiting Fee', 'Free', primaryGreen, isFree: true),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹$price',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildTimelineItem(String title, String desc, String time, bool isActive, bool isLast, Color themeColor) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isActive ? themeColor : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isActive ? themeColor : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: isActive ? Colors.black : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: TextStyle(color: isActive ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  style: TextStyle(
                    color: isActive ? Colors.grey.shade600 : Colors.grey.shade400, 
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, Color themeColor, {bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: isFree ? themeColor : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isFree ? themeColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
