import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stream of services owned by current shop
// Stream of services owned by current shop
final shopServicesStreamProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('services')
      .where('ownerId', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
});

// Stream of payment settings (commission split)
final shopPaymentSettingsStreamProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  return FirebaseFirestore.instance
      .collection('payment_settings')
      .doc('config')
      .snapshots()
      .map((doc) => doc.exists ? (doc.data() ?? {}) : {});
});

// Stream of all bookings
final allBookingsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('bookings')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
            ...doc.data(),
            'id': doc.id,
          }).toList());
});

// Stream of settlements
final allSettlementsStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('payment_settlements')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
            ...doc.data(),
            'id': doc.id,
          }).toList());
});

// Stream of all services map (id -> data)
final allServicesMapStreamProvider = StreamProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('services').snapshots().map((snapshot) {
    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in snapshot.docs) {
      map[doc.id] = {
        ...doc.data(),
        'id': doc.id,
      };
    }
    return map;
  });
});

// Stream of all users map (id -> data)
final allUsersMapStreamProvider = StreamProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((snapshot) {
    final Map<String, Map<String, dynamic>> map = {};
    for (var doc in snapshot.docs) {
      map[doc.id] = {
        ...doc.data(),
        'id': doc.id,
      };
    }
    return map;
  });
});

class ShopPaymentDetailsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const ShopPaymentDetailsScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<ShopPaymentDetailsScreen> createState() => _ShopPaymentDetailsScreenState();
}

class _ShopPaymentDetailsScreenState extends ConsumerState<ShopPaymentDetailsScreen> {
  static const primaryColor = Color(0xFF2029C5);
  static const upiColor = Color(0xFF6C63FF);
  static const successColor = Color(0xFF10B981);
  static const warningColor = Color(0xFFF59E0B);

  String _selectedFilter = 'All'; // 'All', 'Received', 'Pending'

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

    final ownedServiceIdsAsync = ref.watch(shopServicesStreamProvider);
    final settingsAsync = ref.watch(shopPaymentSettingsStreamProvider);
    final bookingsAsync = ref.watch(allBookingsStreamProvider);
    final settlementsAsync = ref.watch(allSettlementsStreamProvider);
    final servicesMapAsync = ref.watch(allServicesMapStreamProvider);
    final usersMapAsync = ref.watch(allUsersMapStreamProvider);

    final bool isInitialLoading = ownedServiceIdsAsync.isLoading &&
        settingsAsync.isLoading &&
        bookingsAsync.isLoading;

    final List<String> ownedServiceIds = ownedServiceIdsAsync.value ?? [];
    final Map<String, dynamic> settingsData = settingsAsync.value ?? {};
    final List<Map<String, dynamic>> allBookings = bookingsAsync.value ?? [];
    final List<Map<String, dynamic>> allSettlements = settlementsAsync.value ?? [];
    final Map<String, Map<String, dynamic>> servicesMap = servicesMapAsync.value ?? {};
    final Map<String, Map<String, dynamic>> usersMap = usersMapAsync.value ?? {};

    final double shopPercent = (settingsData['shopPercent'] is num)
        ? (settingsData['shopPercent'] as num).toDouble()
        : 70.0;
    final double adminPercent = (settingsData['adminShopPercent'] is num)
        ? (settingsData['adminShopPercent'] as num).toDouble()
        : (100.0 - shopPercent);

    // 1. Filter ONLY bookings that belong to this shop's listed services
    final shopBookings = allBookings.where((b) {
      final sId = b['serviceId']?.toString();
      final bOwnerId = b['ownerId']?.toString();
      final bShopId = b['shopId']?.toString();
      return (sId != null && ownedServiceIds.contains(sId)) ||
          bOwnerId == user.uid ||
          bShopId == user.uid;
    }).toList();

    // 2. Filter settlements that belong to this shop or its services
    final shopSettlements = allSettlements.where((s) {
      final sId = s['serviceId']?.toString();
      final sOwnerId = s['ownerId']?.toString();
      final sShopId = s['shopId']?.toString();
      return (sId != null && ownedServiceIds.contains(sId)) ||
          sOwnerId == user.uid ||
          sShopId == user.uid;
    }).toList();

    // 3. Build combined transaction list
    final List<Map<String, dynamic>> combinedList = [];

    // Add existing settlements
    for (var settlement in shopSettlements) {
      final double amount = (settlement['amount'] is num)
          ? (settlement['amount'] as num).toDouble()
          : double.tryParse(settlement['amount']?.toString() ?? '0') ?? 0.0;
      final double shopShare = (settlement['shopShare'] is num)
          ? (settlement['shopShare'] as num).toDouble()
          : amount * (shopPercent / 100.0);
      final double adminShare = (settlement['adminShare'] is num)
          ? (settlement['adminShare'] as num).toDouble()
          : amount * (adminPercent / 100.0);

      combinedList.add({
        ...settlement,
        'amount': amount,
        'shopShare': shopShare,
        'adminShare': adminShare,
        'isDynamic': false,
      });
    }

    // Add bookings (both completed and pending) that don't have settlements yet
    for (var booking in shopBookings) {
      final hasSettlement = shopSettlements.any((s) => s['bookingId'] == booking['id']);
      if (!hasSettlement) {
        final totalVal = booking['totalPrice'] ?? booking['price'] ?? 0;
        final double amount = (totalVal is num)
            ? totalVal.toDouble()
            : double.tryParse(totalVal.toString()) ?? 0.0;
        final double shopShare = amount * (shopPercent / 100.0);
        final double adminShare = amount * (adminPercent / 100.0);
        final method = (booking['paymentMethod'] ?? 'upi').toString().toLowerCase();
        final rawPaymentStatus = (booking['paymentStatus'] ?? '').toString().toLowerCase();
        final bool hasRazorpayId = booking['razorpayPaymentId'] != null;
        final bool isOnlinePayment = method.contains('upi') ||
            method.contains('online') ||
            method.contains('razorpay') ||
            hasRazorpayId ||
            rawPaymentStatus == 'paid';

        final bStatus = (booking['status'] ?? '').toString().toLowerCase();
        final isCompleted = bStatus == 'completed';

        // Online payment goes directly to admin, so it is received!
        final bool isReceived = isOnlinePayment || isCompleted;

        combinedList.add({
          'id': 'sim_${booking['id']}',
          'bookingId': booking['id'],
          'serviceId': booking['serviceId'],
          'serviceTitle': booking['title'] ?? 'Workshop Service',
          'customerName': booking['customerName'] ?? booking['userName'] ?? 'Customer',
          'paymentMethod': method,
          'amount': amount,
          'shopShare': shopShare,
          'adminShare': adminShare,
          'settlementStatus': isReceived ? 'received' : 'pending',
          'updatedAt': booking['updatedAt'] ?? booking['createdAt'] ?? Timestamp.now(),
          'isDynamic': true,
          'bookingData': booking,
        });
      }
    }

    // Sort by date descending
    combinedList.sort((a, b) {
      final aTime = a['updatedAt'] as Timestamp?;
      final bTime = b['updatedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    // 4. Calculate stats
    double totalShopEarnings = 0;
    double totalReceived = 0;
    double totalPending = 0;
    int completedOrdersCount = 0;

    for (var item in combinedList) {
      final double amount = (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
      final double shopShare = (item['shopShare'] is num)
          ? (item['shopShare'] as num).toDouble()
          : (amount * (shopPercent / 100.0));
      final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
      final isSettled = (status.contains('sent') || status == 'completed' || status == 'paid' || status == 'received');

      totalShopEarnings += shopShare;

      if (isSettled) {
        totalReceived += shopShare;
        completedOrdersCount++;
      } else {
        totalPending += shopShare;
      }
    }

    // Filter by tab
    final filteredList = combinedList.where((item) {
      final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
      final isSettled = (status.contains('sent') || status == 'completed' || status == 'paid' || status == 'received');

      if (_selectedFilter == 'Received') return isSettled;
      if (_selectedFilter == 'Pending') return !isSettled;
      return true;
    }).toList();

    return Scaffold(
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
          'Shop Payment Info',
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
        child: isInitialLoading
            ? _buildSkeletonLoader()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Gradient Overview Card
                    _buildEarningsCard(
                      totalShopEarnings: totalShopEarnings,
                      totalReceived: totalReceived,
                      totalPending: totalPending,
                      completedOrdersCount: completedOrdersCount,
                      shopPercent: shopPercent,
                      adminPercent: adminPercent,
                    ),

                    // 2. Filter Controls
                    _buildFilterRow(),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        'Recent Settlements & Payments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    // 3. Transaction List
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
                          return _buildTransactionItem(
                            context,
                            filteredList[index],
                            shopPercent: shopPercent,
                            adminPercent: adminPercent,
                            servicesMap: servicesMap,
                            usersMap: usersMap,
                            allBookings: allBookings,
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEarningsCard({
    required double totalShopEarnings,
    required double totalReceived,
    required double totalPending,
    required int completedOrdersCount,
    required double shopPercent,
    required double adminPercent,
  }) {
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
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.03),
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
                          'TOTAL SHOP EARNINGS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalShopEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Shop ${shopPercent.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Translucent Sub-Metrics Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricColumn('Today\'s Revenue', '₹${totalReceived.toStringAsFixed(0)}'),
                      Container(height: 32, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                      _buildMetricColumn('Completed Services', '$completedOrdersCount Orders'),
                      Container(height: 32, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                      _buildMetricColumn('Pending Payout', '₹${totalPending.toStringAsFixed(0)}'),
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

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: ['All', 'Received', 'Pending'].map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              selected: isSelected,
              selectedColor: primaryColor,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.grey.shade200,
                ),
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  String _resolveServiceName(
    Map<String, dynamic> item,
    Map<String, Map<String, dynamic>> servicesMap,
    List<Map<String, dynamic>> allBookings,
  ) {
    final direct = (item['serviceTitle'] ?? item['serviceName'] ?? item['title'] ?? item['name'])?.toString().trim();
    if (direct != null && direct.isNotEmpty && direct != 'Workshop Service' && direct != 'Service') {
      return direct;
    }

    Map<String, dynamic>? bData = item['bookingData'] as Map<String, dynamic>?;
    final bId = (item['bookingId'] ?? item['id'])?.toString();
    if ((bData == null || bData.isEmpty) && bId != null && bId.isNotEmpty) {
      try {
        bData = allBookings.firstWhere(
          (b) => b['id'] == bId || b['bookingId'] == bId,
          orElse: () => <String, dynamic>{},
        );
      } catch (_) {}
    }

    if (bData != null && bData.isNotEmpty) {
      final bTitle = (bData['title'] ?? bData['serviceTitle'] ?? bData['serviceName'] ?? bData['name'])?.toString().trim();
      if (bTitle != null && bTitle.isNotEmpty && bTitle != 'Workshop Service' && bTitle != 'Service') {
        return bTitle;
      }
    }

    final sId = (item['serviceId'] ?? bData?['serviceId'])?.toString();
    if (sId != null && servicesMap.containsKey(sId)) {
      final sData = servicesMap[sId];
      final sName = (sData?['name'] ?? sData?['title'] ?? sData?['serviceName'])?.toString().trim();
      if (sName != null && sName.isNotEmpty) {
        return sName;
      }
    }

    return (direct != null && direct.isNotEmpty) ? direct : 'Workshop Service';
  }

  String _resolveCustomerName(
    Map<String, dynamic> item,
    Map<String, Map<String, dynamic>> usersMap,
    List<Map<String, dynamic>> allBookings,
  ) {
    final direct = (item['customerName'] ?? item['userName'] ?? item['customer'])?.toString().trim();
    if (direct != null && direct.isNotEmpty && direct.toLowerCase() != 'customer') {
      return direct;
    }

    Map<String, dynamic>? bData = item['bookingData'] as Map<String, dynamic>?;
    final bId = (item['bookingId'] ?? item['id'])?.toString();
    if ((bData == null || bData.isEmpty) && bId != null && bId.isNotEmpty) {
      try {
        bData = allBookings.firstWhere(
          (b) => b['id'] == bId || b['bookingId'] == bId,
          orElse: () => <String, dynamic>{},
        );
      } catch (_) {}
    }

    if (bData != null && bData.isNotEmpty) {
      final bCust = (bData['customerName'] ?? bData['userName'] ?? bData['customer'] ?? bData['name'])?.toString().trim();
      if (bCust != null && bCust.isNotEmpty && bCust.toLowerCase() != 'customer') {
        return bCust;
      }
    }

    final uId = (item['userId'] ?? bData?['userId'])?.toString();
    if (uId != null && usersMap.containsKey(uId)) {
      final uData = usersMap[uId];
      final uName = (uData?['name'] ?? uData?['userName'] ?? uData?['displayName'] ?? uData?['fullName'])?.toString().trim();
      if (uName != null && uName.isNotEmpty && uName.toLowerCase() != 'customer') {
        return uName;
      }
      final email = uData?['email']?.toString();
      if (email != null && email.contains('@')) {
        return email.split('@')[0];
      }
    }

    return (direct != null && direct.isNotEmpty) ? direct : 'Customer';
  }

  Widget _buildTransactionItem(
    BuildContext context,
    Map<String, dynamic> item, {
    required double shopPercent,
    required double adminPercent,
    required Map<String, Map<String, dynamic>> servicesMap,
    required Map<String, Map<String, dynamic>> usersMap,
    required List<Map<String, dynamic>> allBookings,
  }) {
    final title = _resolveServiceName(item, servicesMap, allBookings);
    final customer = _resolveCustomerName(item, usersMap, allBookings);
    final amount = (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
    final shopShare = (item['shopShare'] is num)
        ? (item['shopShare'] as num).toDouble()
        : (amount * (shopPercent / 100.0));

    final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
    final isSettled = (status.contains('sent') || status == 'completed' || status == 'paid' || status == 'received');

    final timeStamp = item['updatedAt'] as Timestamp?;
    final dateStr = timeStamp != null ? DateFormat('d MMM, h:mm a').format(timeStamp.toDate()) : 'Recently';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showBreakdownSheet(
            context,
            item,
            shopPercent: shopPercent,
            adminPercent: adminPercent,
            title: title,
            customer: customer,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSettled ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      isSettled ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                      color: isSettled ? successColor : warningColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$customer • $dateStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${shopShare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total: ₹${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSettled ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSettled ? 'RECEIVED' : 'PENDING',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSettled ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBreakdownSheet(
    BuildContext context,
    Map<String, dynamic> item, {
    required double shopPercent,
    required double adminPercent,
    required String title,
    required String customer,
  }) {
    final bookingId = (item['bookingId'] ?? item['id'] ?? '').toString();
    final method = (item['paymentMethod'] ?? 'Online').toString().toUpperCase();
    final amount = (item['amount'] is num) ? (item['amount'] as num).toDouble() : 0.0;
    final shopShare = (item['shopShare'] is num) ? (item['shopShare'] as num).toDouble() : (amount * (shopPercent / 100.0));
    final adminShare = (item['adminShare'] is num) ? (item['adminShare'] as num).toDouble() : (amount * (adminPercent / 100.0));
    final status = (item['settlementStatus'] ?? '').toString().toLowerCase();
    final isSettled = (status == 'sent' || status == 'completed' || status == 'paid' || status == 'received');

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSettled ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSettled ? 'SETTLED' : 'PENDING SETTLEMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSettled ? const Color(0xFF065F46) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: $customer  •  ID: $bookingId',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),

              // Breakdown Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildBreakdownRow('Total Service Price', '₹${amount.toStringAsFixed(0)}', isBold: true),
                    const Divider(height: 20),
                    _buildBreakdownRow(
                      'Shop Share (${shopPercent.toStringAsFixed(0)}%)',
                      '₹${shopShare.toStringAsFixed(0)}',
                      textColor: const Color(0xFF059669),
                      isBold: true,
                    ),
                    const SizedBox(height: 10),
                    _buildBreakdownRow(
                      'Admin Commission (${adminPercent.toStringAsFixed(0)}%)',
                      '₹${adminShare.toStringAsFixed(0)}',
                      textColor: const Color(0xFF4338CA),
                    ),
                    const Divider(height: 20),
                    _buildBreakdownRow('Payment Method', method),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: textColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Payment Records Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            Text(
              'Payments from your listed workshop services will automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40.0),
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }
}
