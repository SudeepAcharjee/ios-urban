import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'worker_notifications_screen.dart';
import '../viewmodels/worker_provider.dart';
import 'worker_task_detail_screen.dart';
import '../../home/widgets/location_selector_sheet.dart';
import 'worker_payment_details.dart';
import 'worker_disabled_overlay.dart';
import 'worker_tasks_screen.dart';


class WorkerHomeScreen extends ConsumerStatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  ConsumerState<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends ConsumerState<WorkerHomeScreen> {
  String _currentStatus = 'Available';

  static const primaryColor = Color(0xFF2029C5);

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
      final status = doc.data()?['status'] as String?;
      if (status != null && mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateWorkerStatus(String status) async {
    setState(() => _currentStatus = status);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .update({'status': status});
    } catch (_) {}
  }

  void _showLocationSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationSelectorSheet(),
    );
  }



  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider).value;
    final fullLocation = userData?['location'] ?? 'Set Location';
    String location = fullLocation;
    if (fullLocation != 'Set Location') {
      final parts = fullLocation.split(',');
      final cleanParts = parts.map((p) {
        return p.replaceAll(RegExp(r'\b\d{6}\b'), '').trim();
      }).where((p) {
        final lp = p.toLowerCase();
        return p.isNotEmpty && 
               !p.contains('+') && 
               lp != 'india';
      }).toList();
      
      if (cleanParts.isNotEmpty) {
        location = cleanParts.length > 1
            ? '${cleanParts[0]}, ${cleanParts[1]}'
            : cleanParts[0];
      }
    }

    final reviewsAsync = ref.watch(workerReviewsProvider);
    final tasksAsync = ref.watch(workerAssignedTasksProvider);
    final completedTasksAsync = ref.watch(workerCompletedTasksProvider);
    final settlementsAsync = ref.watch(workerSettlementsStreamProvider);
    final bookingsAsync = ref.watch(workerBookingsStreamProvider);

    final reviews = reviewsAsync.value ?? [];
    final completedTasks = completedTasksAsync.value ?? [];
    final settlements = settlementsAsync.value ?? [];
    final bookings = bookingsAsync.value ?? [];

    double avgRating = 0.0;
    if (reviews.isNotEmpty) {
      double sum = 0.0;
      for (var r in reviews) {
        sum += (r['technicianRating'] ?? 5.0).toDouble();
      }
      avgRating = sum / reviews.length;
    }

    double netEarnings = 0.0;
    if (bookings.isNotEmpty) {
      final completedBookings = bookings.where((b) {
        final status = (b['status'] ?? '').toString();
        return status == 'Completed' || status == 'Pending Verification';
      }).toList();

      final List<Map<String, dynamic>> combinedList = [];
      for (var settlement in settlements) {
        combinedList.add({
          ...settlement,
          'isDynamic': false,
        });
      }

      for (var booking in completedBookings) {
        final hasSettlement = settlements.any((s) => s['bookingId'] == booking['id']);
        if (!hasSettlement) {
          final totalVal = booking['totalPrice'] ?? booking['totalAmount'] ?? 0;
          final double amount = (totalVal is num) ? totalVal.toDouble() : double.tryParse(totalVal.toString()) ?? 0.0;
          final double workerShare = amount * 0.70;
          final double adminShare = amount * 0.30;
          final method = (booking['paymentMethod'] ?? 'upi').toString().toLowerCase();

          combinedList.add({
            'paymentMethod': method,
            'amount': amount,
            'workerShare': workerShare,
            'adminShare': adminShare,
            'settlementStatus': 'pending',
          });
        }
      }

      double totalUpiIncomeReceived = 0.0;
      double totalUpiIncomePending = 0.0;
      double totalCashWorkerShare = 0.0;

      for (var item in combinedList) {
        final method = (item['paymentMethod'] ?? 'upi').toString().toLowerCase();
        final double workerShare = (item['workerShare'] is num) ? item['workerShare'].toDouble() : 0.0;
        final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
        final isSettled = (status == 'sent' || status == 'completed' || status == 'paid' || status == 'received');

        if (method == 'upi') {
          if (isSettled) {
            totalUpiIncomeReceived += workerShare;
          } else {
            totalUpiIncomePending += workerShare;
          }
        } else if (method == 'cash') {
          totalCashWorkerShare += workerShare;
        }
      }

      netEarnings = totalUpiIncomeReceived + totalUpiIncomePending + totalCashWorkerShare;
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
            child: Column(
          children: [
            // 🏷️ Premium Header
            Container(
              padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 45),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A114D), // Dark Navy
                    Color(0xFF1E3A8A), // Royal Blue
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showLocationSelector(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Location',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.orangeAccent, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      location,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.7), size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WorkerNotificationsScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                              if (ref.watch(unreadWorkerNotificationsCountProvider) > 0)
                                const Positioned(
                                  right: 2,
                                  top: 2,
                                  child: CircleAvatar(radius: 4.5, backgroundColor: Colors.redAccent),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 📊 Summary Card (Overlapping)
            Transform.translate(
              offset: const Offset(0, -25),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. Earnings Column
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkerPaymentDetailsScreen(),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7), // Light green
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF15803D), // Green
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'View Earnings',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${netEarnings.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Total Earnings',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    Container(width: 1, height: 60, color: const Color(0xFFF1F5F9)),

                    // 2. Rating Column
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFEF3C7), // Light yellow
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFD97706), // Yellow/amber
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your Rating',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(${reviews.length} Reviews)',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(width: 1, height: 60, color: const Color(0xFFF1F5F9)),

                    // 3. Tasks Column
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE), // Light blue
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.task_alt_rounded,
                              color: Color(0xFF2563EB), // Blue
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tasks Completed',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${completedTasks.length}',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total Tasks',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🕒 Duty Status Section
                  const Text(
                    'Duty Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        _buildStatusOption('Online', Colors.green),
                        Container(width: 1, height: 40, color: const Color(0xFFF1F5F9)),
                        _buildStatusOption('Offline', Colors.grey),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // 📋 Assigned Services Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assigned Services',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WorkerTasksScreen(showAppBar: true),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🛠️ Service Cards (Real Data)
                  tasksAsync.when(
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 50, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                const Text('No active tasks assigned', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 260, // Define height for horizontal list
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: tasks.map((task) {
                              return _buildServiceCard(task);
                            }).toList(),
                          ),
                        ),
                      );


                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),

                  const SizedBox(height: 25),
                  
                  // 🌟 Recent Reviews Section
                  reviewsAsync.when(
                    data: (reviews) {
                      return Column(
                        children: [
                          _buildRatingsSummaryCard(reviews: reviews),
                          if (reviews.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('No reviews yet', style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ...reviews.take(3).map((review) => _buildReviewCard(review)).toList(),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
      const PendingCashPaymentOverlay(),
    ]);
  }

  Widget _buildStatusOption(String status, Color color) {
    final bool isSelected = (status == 'Online' && (_currentStatus == 'Available' || _currentStatus == 'Busy')) ||
                            (status == 'Offline' && _currentStatus == 'Offline');
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateWorkerStatus(status == 'Online' ? 'Available' : 'Offline'),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.14) : color.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color.withOpacity(0.6) : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected 
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> task) {
    final String title = task['title'] ?? 'Service';
    final String time = task['time'] ?? 'Upcoming';
    final String price = '₹${task['totalPrice'] ?? '0'}';
    final String location = task['address'] ?? 'Customer Location';
    final String image = task['imagePath'] ?? 'images/services/car_wash_service.png';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkerTaskDetailScreen(taskData: task),
          ),
        );
      },
      child: Container(
        width: 320, // Fixed width for horizontal scrolling
        margin: const EdgeInsets.only(bottom: 20, right: 16), // Added right margin for horizontal spacing
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📸 Enhanced Service Image
                Hero(
                  tag: 'task_image_${task['id']}',
                  child: Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: image.startsWith('http') 
                            ? NetworkImage(image) as ImageProvider
                            : AssetImage(image),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 17, 
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              price,
                              style: const TextStyle(color: Color(0xFF15803D), fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (task['status']?.toString().toUpperCase() == 'COMPLETED')
                                  ? Colors.green.withOpacity(0.1)
                                  : primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (task['status']?.toString().toUpperCase() == 'COMPLETED')
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                                if (task['status']?.toString().toUpperCase() == 'COMPLETED')
                                  const SizedBox(width: 4),
                                Text(
                                  (task['status'] ?? 'CONFIRMED').toString().toUpperCase(),
                                  style: TextStyle(
                                    color: (task['status']?.toString().toUpperCase() == 'COMPLETED')
                                        ? Colors.green
                                        : primaryColor, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.w900
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 14, color: primaryColor.withOpacity(0.6)),
                          const SizedBox(width: 6),
                          Text(
                            time, 
                            style: TextStyle(
                              color: Colors.grey.shade600, 
                              fontSize: 12, 
                              fontWeight: FontWeight.w600
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade500, 
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
  
            // 👤 Customer Section
            if (task['userId'] != null && task['userId'].toString().isNotEmpty)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(task['userId']).get(),
                builder: (context, snapshot) {
                  final userData = snapshot.data?.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? task['userName'] ?? 'Customer';
                  final profilePic = userData?['profilePic'];
                  
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor.withOpacity(0.1)),
                        ),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white,
                          backgroundImage: (profilePic != null && profilePic.isNotEmpty) ? NetworkImage(profilePic) : null,
                          child: (profilePic == null || profilePic.isEmpty) ? const Icon(Icons.person, size: 12, color: Colors.grey) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SERVICE FOR',
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            Text(
                              name, 
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13, 
                                fontWeight: FontWeight.w800, 
                                color: Color(0xFF334155)
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      
                      // 🔥 View Details Action
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkerTaskDetailScreen(taskData: task),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2563EB), // Royal Blue
                                Color(0xFF1D4ED8), // Deep Blue
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final int rating = (review['technicianRating'] ?? 5).toInt();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), // More compact vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ensure height is based on content
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 👤 Avatar with Light Blue Background
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: review['userProfilePic'] != null && review['userProfilePic'] != ''
                      ? Image.network(review['userProfilePic'], fit: BoxFit.cover)
                      : const Icon(Icons.person, color: Color(0xFF3B82F6), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              // 👤 Name and Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      review['userName'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review['date'] ?? 'October 5, 2023',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // ⭐ Stars on the Right (Changed to Blue)
              Row(
                children: List.generate(5, (index) => Icon(
                  Icons.star_rounded,
                  color: index < rating ? Colors.amber : const Color(0xFFE5E7EB),
                  size: 16,
                )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 💬 Comment Text
          Text(
            (review['comment'] == null || review['comment'] == '') ? 'No comment provided' : review['comment'],
            style: TextStyle(
              fontSize: 13, 
              color: Colors.grey.shade500, 
              height: 1.5,
              fontStyle: (review['comment'] == null || review['comment'] == '') ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  Widget _buildRatingsSummaryCard({required List<Map<String, dynamic>> reviews}) {
    double average = 0.0;
    if (reviews.isNotEmpty) {
      double sum = 0;
      for (var r in reviews) {
        sum += (r['technicianRating'] ?? 5).toDouble();
      }
      average = sum / reviews.length;
    }

    final String avgStr = average.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews and ratings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                avgStr,
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (index) => Icon(
                      Icons.star_rounded,
                      color: index < average.floor() ? Colors.amber : const Color(0xFFE5E7EB),
                      size: 28,
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on ${reviews.length} ratings',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 30),
            _buildRatingProgressRow('Reliability', 0.82, '4.1', Colors.orange),
            const SizedBox(height: 18),
            _buildRatingProgressRow('Payout rating', 0.86, '4.3', const Color(0xFF10B981)),
            const SizedBox(height: 18),
            _buildRatingProgressRow('Positive solutions', 0.82, '4.1', const Color(0xFF10B981)),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingProgressRow(String label, double progress, String rating, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            Text(
              rating,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
