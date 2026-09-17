import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'shop_booking_detail_screen.dart';

class ShopBookingsScreen extends StatefulWidget {
  final bool showBackButton;

  const ShopBookingsScreen({
    super.key,
    this.showBackButton = false,
  });

  @override
  State<ShopBookingsScreen> createState() => _ShopBookingsScreenState();
}

class _ShopBookingsScreenState extends State<ShopBookingsScreen> {
  static const primaryColor = Color(0xFF2029C5);
  String _selectedFilter = 'All'; // 'All', 'Pending', 'In Progress', 'Completed', 'Cancelled'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view bookings')),
      );
    }

    final uid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 0,
        centerTitle: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Workshop Bookings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('ownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, activeSnap) {
          final activeDocs = activeSnap.data?.docs ?? [];
          final activeServiceIds = activeDocs.map((d) => d.id).toSet();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
            builder: (context, bookingsSnap) {
              if (bookingsSnap.connectionState == ConnectionState.waiting && !bookingsSnap.hasData) {
                return const Center(child: CircularProgressIndicator(color: primaryColor));
              }

              final allBookings = bookingsSnap.data?.docs ?? [];

              // Filter bookings belonging to this shop
              final shopBookings = allBookings.where((doc) {
                final data = doc.data();
                final bShopId = data['shopId']?.toString();
                final bOwnerId = data['ownerId']?.toString();
                final bServiceId = data['serviceId']?.toString();
                return bShopId == uid ||
                    bOwnerId == uid ||
                    (bServiceId != null && activeServiceIds.contains(bServiceId));
              }).toList();

              // Sort by createdAt descending (newest first)
              shopBookings.sort((a, b) {
                final aTime = (a.data()['createdAt'] is Timestamp)
                    ? (a.data()['createdAt'] as Timestamp).toDate()
                    : DateTime(2000);
                final bTime = (b.data()['createdAt'] is Timestamp)
                    ? (b.data()['createdAt'] as Timestamp).toDate()
                    : DateTime(2000);
                return bTime.compareTo(aTime);
              });

              // Status Counts
              final countAll = shopBookings.length;
              final countPending = shopBookings.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'pending').length;
              final countActive = shopBookings.where((d) {
                final st = (d.data()['status'] ?? '').toString().toLowerCase();
                return st == 'confirmed' || st == 'assigned' || st == 'in progress' || st == 'in-progress';
              }).length;
              final countCompleted = shopBookings.where((d) {
                final st = (d.data()['status'] ?? '').toString().toLowerCase();
                return st == 'completed' || st == 'job completed';
              }).length;
              final countCancelled = shopBookings.where((d) => (d.data()['status'] ?? '').toString().toLowerCase() == 'cancelled').length;

              // Filter list based on selected filter
              final filteredByTab = shopBookings.where((doc) {
                final st = (doc.data()['status'] ?? '').toString().toLowerCase();
                if (_selectedFilter == 'Pending') {
                  return st == 'pending';
                } else if (_selectedFilter == 'Active') {
                  return st == 'confirmed' || st == 'assigned' || st == 'in progress' || st == 'in-progress';
                } else if (_selectedFilter == 'Completed') {
                  return st == 'completed' || st == 'job completed';
                } else if (_selectedFilter == 'Cancelled') {
                  return st == 'cancelled';
                }
                return true;
              }).toList();

              // Search query filter
              final filteredBookings = filteredByTab.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data();
                final title = (data['title'] ?? data['serviceName'] ?? '').toString().toLowerCase();
                final customer = (data['userName'] ?? data['customerName'] ?? '').toString().toLowerCase();
                final vehicle = (data['carModel'] ?? data['vehicleName'] ?? '').toString().toLowerCase();
                final id = doc.id.toLowerCase();
                final q = _searchQuery.toLowerCase();
                return title.contains(q) || customer.contains(q) || vehicle.contains(q) || id.contains(q);
              }).toList();

              return Column(
                children: [
                  // SEARCH BAR & FILTER CHIPS CONTAINER
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        // Search Box
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            decoration: InputDecoration(
                              hintText: 'Search by customer, service or vehicle...',
                              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Filter Chips Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', countAll),
                              _buildFilterChip('Pending', countPending),
                              _buildFilterChip('Active', countActive),
                              _buildFilterChip('Completed', countCompleted),
                              _buildFilterChip('Cancelled', countCancelled),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // BOOKINGS LIST
                  Expanded(
                    child: filteredBookings.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                            itemCount: filteredBookings.length,
                            itemBuilder: (context, index) {
                              final doc = filteredBookings[index];
                              return _buildBookingCard(context, doc.id, doc.data());
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (sel) {
          if (sel) setState(() => _selectedFilter = label);
        },
        selectedColor: primaryColor,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : Colors.grey.shade700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                size: 48,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No Results Found'
                  : (_selectedFilter == 'All' ? 'No Bookings Yet' : 'No $_selectedFilter Bookings'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different keyword.'
                  : 'Customer booking orders will appear here automatically with live tracking.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, String bookingId, Map<String, dynamic> data) {
    final title = (data['title'] ?? data['serviceName'] ?? 'Service').toString();
    final customerName = (data['userName'] ?? data['customerName'] ?? 'Customer').toString();
    final price = (data['totalPrice'] ?? data['price'] ?? 0).toString();
    final status = (data['status'] ?? 'Pending').toString();
    final rawDate = data['date'] ?? data['bookingDate'];
    final timeSlot = (data['time'] ?? data['timeSlot'] ?? '').toString();
    final vehicleModel = (data['carModel'] ?? data['vehicleName'] ?? data['vehicle'] ?? '').toString();

    String dateStr = '';
    if (rawDate != null) {
      if (rawDate is Timestamp) {
        dateStr = DateFormat('d MMM, yyyy').format(rawDate.toDate());
      } else {
        dateStr = rawDate.toString();
      }
    }

    Color statusColor;
    Color statusBg;
    final stLower = status.toLowerCase();
    if (stLower == 'pending') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    } else if (stLower == 'confirmed' || stLower == 'assigned') {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    } else if (stLower == 'in progress' || stLower == 'in-progress') {
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFEDE9FE);
    } else if (stLower == 'completed' || stLower == 'job completed') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFD1FAE5);
    } else {
      statusColor = Colors.grey.shade700;
      statusBg = Colors.grey.shade100;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopBookingDetailScreen(
                  bookingId: bookingId,
                  bookingData: data,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      customerName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    if (vehicleModel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        vehicleModel,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (dateStr.isNotEmpty || timeSlot.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        [if (dateStr.isNotEmpty) dateStr, if (timeSlot.isNotEmpty) timeSlot].join(' • '),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Colors.grey.shade400,
                        ),
                      ],
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
}
