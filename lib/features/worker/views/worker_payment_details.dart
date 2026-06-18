import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'worker_disabled_overlay.dart';


final workerSettlementsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('payment_settlements')
      .where('workerId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList());
});

final workerBookingsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('bookings')
      .where('workerId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList());
});

class WorkerPaymentDetailsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const WorkerPaymentDetailsScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<WorkerPaymentDetailsScreen> createState() => _WorkerPaymentDetailsScreenState();
}

class _WorkerPaymentDetailsScreenState extends ConsumerState<WorkerPaymentDetailsScreen> {
  static const primaryColor = Color(0xFF2029C5);
  static const upiColor = Color(0xFF6C63FF);
  static const successColor = Color(0xFF10B981);
  static const warningColor = Color(0xFFF59E0B);
  
  String _selectedFilter = 'All'; // 'All', 'Received', 'Pending'
  String _selectedTimeFilter = 'All Time'; // 'All Time', 'Daily', 'Weekly', 'Monthly'

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Authentication required. Please log in again.'),
        ),
      );
    }

    final settlementsAsync = ref.watch(workerSettlementsStreamProvider);
    final bookingsAsync = ref.watch(workerBookingsStreamProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: widget.showBackButton
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
                ),
              )
            : null,
        title: const Text(
          'Payment Info',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: widget.showBackButton,
        child: settlementsAsync.when(
        data: (settlements) {
          return bookingsAsync.when(
            data: (bookings) {
              // 1. Find all bookings that the worker completed or submitted for verification
              final completedBookings = bookings.where((b) {
                final status = (b['status'] ?? '').toString();
                return status == 'Completed' || status == 'Pending Verification';
              }).toList();

              // 2. Build the combined list of settlements (both real & simulated pending)
              final List<Map<String, dynamic>> combinedList = [];

              // Add all existing settlement documents
              for (var settlement in settlements) {
                combinedList.add({
                  ...settlement,
                  'isDynamic': false,
                });
              }

              // Add simulated settlements for completed tasks that don't have settlements yet
              for (var booking in completedBookings) {
                final hasSettlement = settlements.any((s) => s['bookingId'] == booking['id']);
                if (!hasSettlement) {
                  final totalVal = booking['totalPrice'] ?? booking['totalAmount'] ?? 0;
                  final double amount = (totalVal is num) ? totalVal.toDouble() : double.tryParse(totalVal.toString()) ?? 0.0;
                  final double workerShare = amount * 0.70;
                  final double adminShare = amount * 0.30;
                  final method = (booking['paymentMethod'] ?? 'upi').toString().toLowerCase();

                  combinedList.add({
                    'id': 'temp_${booking['id']}',
                    'bookingId': booking['id'],
                    'serviceId': booking['serviceId'],
                    'paymentMethod': method,
                    'amount': amount,
                    'workerShare': workerShare,
                    'adminShare': adminShare,
                    'settlementAmount': method == 'upi' ? workerShare : adminShare,
                    'settlementFlow': method == 'upi' ? 'send' : 'receive',
                    'settlementParty': method == 'upi' ? 'worker' : 'admin',
                    'settlementStatus': 'pending',
                    'updatedAt': booking['updatedAt'] ?? booking['submittedAt'] ?? Timestamp.now(),
                    'updatedByName': 'System (Awaiting Admin)',
                    'isDynamic': true,
                    'bookingData': booking,
                  });
                }
              }

              // Sort by updatedAt descending
              combinedList.sort((a, b) {
                final aTime = a['updatedAt'] as Timestamp?;
                final bTime = b['updatedAt'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              // Calculate stats based on time filter
              double totalUpiIncomeReceived = 0;
              double totalUpiIncomePending = 0;
              double totalCollectedUpi = 0;
              int upiReceivedCount = 0;
              int upiPendingCount = 0;

              double totalAdminSharePaid = 0;
              double totalAdminShareOwed = 0;
              double totalCollectedCash = 0;
              int cashPaidCount = 0;
              int cashPendingCount = 0;
              double totalCashWorkerShare = 0;

              // Filter overview and chart data by selected time period
              final timeFilteredOverviewList = combinedList.where((item) {
                bool matchesTime = true;
                DateTime time = DateTime.now();
                final timestamp = item['updatedAt'] ?? item['createdAt'];
                if (timestamp is Timestamp) {
                  time = timestamp.toDate();
                } else {
                  matchesTime = (_selectedTimeFilter == 'All Time');
                }

                if (matchesTime && _selectedTimeFilter != 'All Time') {
                  final now = DateTime.now();
                  if (_selectedTimeFilter == 'Daily') {
                    final todayStart = DateTime(now.year, now.month, now.day);
                    matchesTime = time.isAfter(todayStart) || time.isAtSameMomentAs(todayStart);
                  } else if (_selectedTimeFilter == 'Weekly') {
                    final sevenDaysAgo = now.subtract(const Duration(days: 7));
                    matchesTime = time.isAfter(sevenDaysAgo);
                  } else if (_selectedTimeFilter == 'Monthly') {
                    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
                    matchesTime = time.isAfter(thirtyDaysAgo);
                  }
                }
                return matchesTime;
              }).toList();

              for (var item in timeFilteredOverviewList) {
                final method = (item['paymentMethod'] ?? 'upi').toString().toLowerCase();
                final double amount = (item['amount'] is num) ? item['amount'].toDouble() : 0.0;
                final double workerShare = (item['workerShare'] is num) ? item['workerShare'].toDouble() : 0.0;
                final double adminShare = (item['adminShare'] is num) ? item['adminShare'].toDouble() : 0.0;
                final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
                final isSettled = (status == 'sent' || status == 'completed' || status == 'paid' || status == 'received');

                if (method == 'upi') {
                  totalCollectedUpi += amount;
                  if (isSettled) {
                    totalUpiIncomeReceived += workerShare;
                    upiReceivedCount++;
                  } else {
                    totalUpiIncomePending += workerShare;
                    upiPendingCount++;
                  }
                } else if (method == 'cash') {
                  totalCollectedCash += amount;
                  totalCashWorkerShare += workerShare;
                  if (isSettled) {
                    totalAdminSharePaid += adminShare;
                    cashPaidCount++;
                  } else {
                    totalAdminShareOwed += adminShare;
                    cashPendingCount++;
                  }
                }
              }

              // Filter documents based on status selection on top of time selection
              final filteredList = timeFilteredOverviewList.where((item) {
                final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
                final isSettled = (status == 'sent' || status == 'completed' || status == 'paid' || status == 'received');
                
                if (_selectedFilter == 'Received') {
                  return isSettled;
                } else if (_selectedFilter == 'Pending') {
                  return !isSettled;
                }
                return true;
              }).toList();

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 💳 Single Premium Overview Card (Total Earnings)
                    _buildSingleEarningsCard(
                      totalUpiIncomeReceived: totalUpiIncomeReceived,
                      totalUpiIncomePending: totalUpiIncomePending,
                      upiCount: upiReceivedCount + upiPendingCount,
                      totalCollectedUpi: totalCollectedUpi,
                      totalAdminSharePaid: totalAdminSharePaid,
                      totalAdminShareOwed: totalAdminShareOwed,
                      cashCount: cashPaidCount + cashPendingCount,
                      totalCollectedCash: totalCollectedCash,
                      totalCashWorkerShare: totalCashWorkerShare,
                    ),

                    // 📊 Payment Methods Donut Graph View
                    _buildGraphCard(
                      upiAmount: totalCollectedUpi,
                      cashAmount: totalCollectedCash,
                    ),

                    // 🎛️ Filter Controls
                    _buildTimeFilterRow(),
                    _buildFilterRow(),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        'Settlement History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    // 📜 Transaction List
                    if (filteredList.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildTransactionItem(context, filteredList[index]);
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
            loading: () => _buildSkeletonLoader(),
            error: (e, s) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading tasks: $e'),
              ),
            ),
          );
        },
        loading: () => _buildSkeletonLoader(),
        error: (e, s) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading settlements: $e'),
          ),
        ),
      ),
      ),
      ),
      const PendingCashPaymentOverlay(),
    ]);
  }

  Widget _buildSingleEarningsCard({
    required double totalUpiIncomeReceived,
    required double totalUpiIncomePending,
    required int upiCount,
    required double totalCollectedUpi,
    required double totalAdminSharePaid,
    required double totalAdminShareOwed,
    required int cashCount,
    required double totalCollectedCash,
    required double totalCashWorkerShare,
  }) {
    final double netEarnings = totalUpiIncomeReceived + totalUpiIncomePending + totalCashWorkerShare;
    final int totalBookings = upiCount + cashCount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            Color(0xFF4F46E5),
            upiColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background accents
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white.withOpacity(0.04),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withOpacity(0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL EARNINGS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${NumberFormat('#,##,###.##').format(netEarnings)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Based on $totalBookings completed services',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                  ),
                  child: Column(
                    children: [
                      // UPI row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: Color(0xFFC7D2FE), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'UPI Payouts',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${(totalUpiIncomeReceived + totalUpiIncomePending).toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Received: ₹${totalUpiIncomeReceived.toStringAsFixed(0)} · Pending: ₹${totalUpiIncomePending.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.white.withOpacity(0.1), height: 1),
                      const SizedBox(height: 12),
                      // Cash row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, color: Color(0xFFA7F3D0), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Cash Income',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${totalCashWorkerShare.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Owed Admin: ₹${totalAdminShareOwed.toStringAsFixed(0)} · Paid: ₹${totalAdminSharePaid.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: totalAdminShareOwed > 0 ? const Color(0xFFFDE047) : Colors.white.withOpacity(0.6),
                                  fontSize: 10,
                                  fontWeight: totalAdminShareOwed > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        children: ['All', 'Received', 'Pending'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                }
              },
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                ),
              ),
              elevation: isSelected ? 4 : 0,
              shadowColor: primaryColor.withOpacity(0.3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedFilter Settlements',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            'Payments settled by admin will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Map<String, dynamic> settlement) {
    final bookingId = settlement['bookingId'] ?? '';
    final paymentMethod = (settlement['paymentMethod'] ?? 'upi').toString().toLowerCase();
    final bool isUpi = paymentMethod == 'upi';

    final shareVal = settlement['workerShare'] ?? settlement['settlementAmount'] ?? 0;
    final double workerShare = (shareVal is num) ? shareVal.toDouble() : double.tryParse(shareVal.toString()) ?? 0.0;
    
    final adminShareVal = settlement['adminShare'] ?? 0;
    final double adminShare = (adminShareVal is num) ? adminShareVal.toDouble() : double.tryParse(adminShareVal.toString()) ?? 0.0;

    final status = (settlement['settlementStatus'] ?? '').toString().toLowerCase();
    final isSettled = (status == 'sent' || status == 'completed' || status == 'paid' || status == 'received');

    DateTime time = DateTime.now();
    final timestamp = settlement['updatedAt'] ?? settlement['createdAt'];
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    }

    final formattedDate = DateFormat('d MMM yyyy, h:mm a').format(time);

    if (settlement['isDynamic'] == true) {
      final booking = settlement['bookingData'] as Map<String, dynamic>;
      final serviceTitle = booking['title'] ?? 'Car Washing Service';
      final bookingImage = booking['imagePath'] ?? booking['imageUrl'];

      return _buildTransactionItemRow(
        context: context,
        settlement: settlement,
        bookingId: bookingId,
        isUpi: isUpi,
        serviceTitle: serviceTitle,
        bookingImage: bookingImage,
        workerShare: workerShare,
        adminShare: adminShare,
        isSettled: isSettled,
        formattedDate: formattedDate,
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('bookings').doc(bookingId).get(),
      builder: (context, bookingSnap) {
        if (bookingSnap.connectionState == ConnectionState.waiting) {
          return _buildTransactionItemSkeleton();
        }

        String serviceTitle = 'Car Washing Service';
        String? bookingImage;
        
        if (bookingSnap.hasData && bookingSnap.data != null && bookingSnap.data!.exists) {
          final bData = bookingSnap.data!.data() as Map<String, dynamic>?;
          serviceTitle = bData?['title'] ?? 'Car Washing Service';
          bookingImage = bData?['imagePath'] ?? bData?['imageUrl'];
        }

        return _buildTransactionItemRow(
          context: context,
          settlement: settlement,
          bookingId: bookingId,
          isUpi: isUpi,
          serviceTitle: serviceTitle,
          bookingImage: bookingImage,
          workerShare: workerShare,
          adminShare: adminShare,
          isSettled: isSettled,
          formattedDate: formattedDate,
        );
      },
    );
  }

  Widget _buildTransactionItemSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          // Icon / Image placeholder
          _ShimmerContainer(width: 52, height: 52, radius: 16),
          SizedBox(width: 16),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerContainer(width: 130, height: 14, radius: 6),
                SizedBox(height: 6),
                _ShimmerContainer(width: 110, height: 11, radius: 6),
                SizedBox(height: 6),
                _ShimmerContainer(width: 140, height: 9, radius: 6),
              ],
            ),
          ),
          SizedBox(width: 12),

          // Amount and Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ShimmerContainer(width: 40, height: 14, radius: 6),
              SizedBox(height: 8),
              _ShimmerContainer(width: 75, height: 18, radius: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItemRow({
    required BuildContext context,
    required Map<String, dynamic> settlement,
    required String bookingId,
    required bool isUpi,
    required String serviceTitle,
    required String? bookingImage,
    required double workerShare,
    required double adminShare,
    required bool isSettled,
    required String formattedDate,
  }) {
    return InkWell(
      onTap: () => _showReceiptDetails(context, settlement, serviceTitle),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon / Image container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isUpi ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                image: bookingImage != null && bookingImage.startsWith('http')
                    ? DecorationImage(image: NetworkImage(bookingImage), fit: BoxFit.cover)
                    : null,
              ),
              child: bookingImage == null
                  ? Icon(
                      isUpi ? Icons.qr_code_2_rounded : Icons.payments_rounded, 
                      color: isUpi ? upiColor : successColor, 
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: #${bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId} · ${isUpi ? "UPI" : "Cash"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Amount and Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${workerShare.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isUpi ? upiColor : successColor,
                  ),
                ),
                if (!isUpi) ...[
                  const SizedBox(height: 2),
                  Text(
                    'To Admin: ₹${adminShare.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSettled 
                        ? successColor.withOpacity(0.12)
                        : (isUpi ? warningColor.withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSettled 
                        ? (isUpi ? 'Received' : 'Settled') 
                        : (isUpi ? 'Receive (Pending)' : 'Send (Owed)'),
                    style: TextStyle(
                      color: isSettled 
                          ? successColor 
                          : (isUpi ? warningColor : const Color(0xFFEF4444)),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDetails(BuildContext context, Map<String, dynamic> settlement, String serviceTitle) {
    final bookingId = settlement['bookingId'] ?? '';
    final paymentMethod = (settlement['paymentMethod'] ?? 'upi').toString().toLowerCase();
    final bool isUpi = paymentMethod == 'upi';

    final shareVal = settlement['workerShare'] ?? settlement['settlementAmount'] ?? 0;
    final double workerShare = (shareVal is num) ? shareVal.toDouble() : double.tryParse(shareVal.toString()) ?? 0.0;
    
    final adminShareVal = settlement['adminShare'] ?? 0;
    final double adminShare = (adminShareVal is num) ? adminShareVal.toDouble() : double.tryParse(adminShareVal.toString()) ?? 0.0;

    final amountVal = settlement['amount'] ?? 0;
    final double amount = (amountVal is num) ? amountVal.toDouble() : double.tryParse(amountVal.toString()) ?? 0.0;

    final status = (settlement['settlementStatus'] ?? 'pending').toString().toUpperCase();
    final isSettled = status == 'SENT' || status == 'COMPLETED' || status == 'PAID' || status == 'RECEIVED';

    DateTime time = DateTime.now();
    final timestamp = settlement['updatedAt'] ?? settlement['createdAt'];
    if (timestamp is Timestamp) {
      time = timestamp.toDate();
    }
    final formattedFullDate = DateFormat('EEEE, d MMMM yyyy, h:mm a').format(time);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottomsheet notch
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              
              // Animated Success/Clock Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isSettled ? successColor : warningColor).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSettled ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                  color: isSettled ? successColor : warningColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                isUpi ? 'UPI Settlement Receipt' : 'Cash Settlement Receipt',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isUpi 
                    ? (isSettled ? 'Funds successfully sent by Admin' : 'Awaiting Admin transfer')
                    : (isSettled ? 'Admin commission received by Admin' : 'Worker must pay commission to Admin'),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Detail fields
              _buildReceiptRow('Service', serviceTitle),
              _buildReceiptRow('Booking ID', '#${bookingId.toUpperCase()}'),
              _buildReceiptRow('Settlement Date', formattedFullDate),
              _buildReceiptRow('Payment Method', isUpi ? 'UPI (Direct to Admin)' : 'Cash (Collected by Worker)'),
              _buildReceiptRow(
                'Status', 
                isUpi 
                    ? (isSettled ? 'SENT TO WORKER' : 'PENDING TRANSFER')
                    : (isSettled ? 'COMMISSION PAID TO ADMIN' : 'COMMISSION OWED TO ADMIN'), 
                valueColor: isSettled ? successColor : warningColor
              ),
              _buildReceiptRow('Updated By', settlement['updatedByName'] ?? 'Urban Service Admin'),
              
              const SizedBox(height: 12),
              
              // Custom dashed line separator
              Row(
                children: List.generate(
                  25,
                  (index) => Expanded(
                    child: Container(
                      color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade300,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Financial Breakdowns
              _buildReceiptRow('Service Total Amount', '₹${amount.toStringAsFixed(2)}', isBold: false),
              _buildReceiptRow(
                isUpi ? 'Admin Commission Share' : 'Commission to Admin', 
                '- ₹${adminShare.toStringAsFixed(2)}', 
                isBold: false, 
                valueColor: Colors.red.shade600
              ),
              const SizedBox(height: 8),
              _buildReceiptRow(
                isUpi ? 'Your Settlement Payout' : 'Your Net Earnings',
                '₹${workerShare.toStringAsFixed(2)}',
                isBold: true,
                valueColor: isUpi ? upiColor : successColor,
                fontSize: 18,
              ),

              const SizedBox(height: 28),
              
              // Close button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CLOSE RECEIPT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(
    String label, 
    String value, {
    bool isBold = false, 
    Color? valueColor,
    double fontSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: fontSize,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 💳 Card Skeleton
          Padding(
            padding: const EdgeInsets.all(20),
            child: _ShimmerContainer(
              width: double.infinity,
              height: 280,
              radius: 28,
            ),
          ),

          // 🎛️ Filter Chips Skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                _ShimmerContainer(width: 55, height: 36, radius: 20),
                const SizedBox(width: 8),
                _ShimmerContainer(width: 85, height: 36, radius: 20),
                const SizedBox(width: 8),
                _ShimmerContainer(width: 80, height: 36, radius: 20),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              'Settlement History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // 📜 Transaction List Skeleton
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Icon / Image placeholder
                    _ShimmerContainer(width: 52, height: 52, radius: 16),
                    const SizedBox(width: 16),
                    
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerContainer(width: 130, height: 14, radius: 6),
                          const SizedBox(height: 6),
                          _ShimmerContainer(width: 110, height: 11, radius: 6),
                          const SizedBox(height: 6),
                          _ShimmerContainer(width: 140, height: 9, radius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount and Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ShimmerContainer(width: 40, height: 14, radius: 6),
                        const SizedBox(height: 8),
                        _ShimmerContainer(width: 75, height: 18, radius: 10),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimeFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All Time', 'Daily', 'Weekly', 'Monthly'].map((filter) {
            final isSelected = _selectedTimeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedTimeFilter = filter;
                    });
                  }
                },
                selectedColor: primaryColor,
                backgroundColor: Colors.white,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                  ),
                ),
                elevation: isSelected ? 4 : 0,
                shadowColor: primaryColor.withOpacity(0.3),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGraphCard({required double upiAmount, required double cashAmount}) {
    final double total = upiAmount + cashAmount;
    final double upiPercent = total > 0 ? (upiAmount / total) * 100 : 0.0;
    final double cashPercent = total > 0 ? (cashAmount / total) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              const Text(
                'Payment Methods Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedTimeFilter,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: DonutChartPainter(upiValue: upiAmount, cashValue: cashAmount),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            total > 0 ? '${upiPercent.toStringAsFixed(0)}%' : '0%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2029C5),
                            ),
                          ),
                          const Text(
                            'UPI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  children: [
                    _buildLegendItem(
                      color: const Color(0xFF2029C5),
                      label: 'UPI Payouts',
                      amount: upiAmount,
                      percentage: upiPercent,
                      icon: Icons.qr_code_2_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildLegendItem(
                      color: const Color(0xFF10B981),
                      label: 'Cash Income',
                      amount: cashAmount,
                      percentage: cashPercent,
                      icon: Icons.payments_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required double amount,
    required double percentage,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _ShimmerContainer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerContainer({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<_ShimmerContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1F5),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double upiValue;
  final double cashValue;

  DonutChartPainter({required this.upiValue, required this.cashValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double total = upiValue + cashValue;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 12.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (total == 0) {
      paint.color = const Color(0xFFE2E8F0);
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final double upiAngle = (upiValue / total) * 2 * 3.141592653589793;
    final double cashAngle = (cashValue / total) * 2 * 3.141592653589793;

    // Draw UPI segment
    paint.color = const Color(0xFF2029C5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.141592653589793 / 2,
      upiAngle,
      false,
      paint,
    );

    // Draw Cash segment
    paint.color = const Color(0xFF10B981);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.141592653589793 / 2 + upiAngle,
      cashAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.upiValue != upiValue || oldDelegate.cashValue != cashValue;
  }
}
