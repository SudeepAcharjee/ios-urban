import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'booking_detail_screen.dart';
import 'categories_screen.dart';
import '../viewmodels/booking_provider.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const BookingsScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'Pending', 'In Progress', 'Completed'];

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF111827);
    const primaryColor = Color(0xFF2029C5);
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton ? IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ) : null,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          // 📑 Tabs Section
          Container(
            height: 65,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                bool isSelected = _selectedTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.grey.shade100,
                          width: 1.5,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: bookingsAsync.when(
              skipLoadingOnReload: true,
              data: (bookings) {
                // 🔍 Filter bookings based on selected tab
                final filteredBookings = bookings.where((b) {
                  final status = (b['status'] ?? 'PENDING').toString().toUpperCase();
                  if (_selectedTab == 'All') return true;
                  if (_selectedTab == 'Pending') return status == 'PENDING';
                  if (_selectedTab == 'In Progress') {
                    return status == 'CONFIRMED' || status == 'IN PROGRESS' || status == 'ON THE WAY';
                  }
                  if (_selectedTab == 'Completed') {
                    return status == 'COMPLETED' || status == 'JOB COMPLETED';
                  }
                  return true;
                }).toList();

                if (filteredBookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey[200]),
                        const SizedBox(height: 20),
                        Text(
                          'No $_selectedTab bookings',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    ref.invalidate(userBookingsProvider);
                    await Future.delayed(const Duration(milliseconds: 1000));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      final String title = booking['title'] ?? 'Service';
                      final String status = booking['status'] ?? 'PENDING';
                      final num rawPrice = booking['totalPrice'] ?? booking['price'] ?? 0;
                      final String amount = '₹${rawPrice.toDouble().toStringAsFixed(2)}';
                      final String date = booking['date'] ?? 'No Date';
                      final String time = booking['time'] ?? 'No Time';
                      final String address = booking['address'] ?? 'Guwahati, Assam';
                      final String bookingId = (booking['bookingId'] ?? booking['id'] ?? 'N/A').toString().toUpperCase();
                      final String imagePath = booking['imagePath'] ?? 'assets/images/car_wash_bg.jpg';
                      
                      return _buildBookingCard(
                        context,
                        booking: booking,
                        title: title,
                        date: date,
                        time: time,
                        address: address,
                        status: status.toUpperCase(),
                        amount: amount,
                        bookingId: bookingId,
                        imagePath: imagePath,
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          
          // Book New Service Button
          Container(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 30 + MediaQuery.of(context).padding.bottom),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoriesScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D39D1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Book New Service',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context, {
    required Map<String, dynamic> booking,
    required String title,
    required String date,
    required String time,
    required String address,
    required String status,
    required String amount,
    required String bookingId,
    required String imagePath,
  }) {
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const primaryColor = Color(0xFF2029C5);
    
    Color statusColor;
    Color statusBgColor;

    if (status == 'CONFIRMED' || status == 'JOB COMPLETED' || status == 'COMPLETED') {
      statusColor = const Color(0xFF2029C5);
      statusBgColor = const Color(0xFFE3F2FD);
    } else if (status == 'CANCELLED' || status == 'BOOKING CANCELLED') {
      statusColor = const Color(0xFFFF5252);
      statusBgColor = const Color(0xFFFFEBEE);
    } else {
      statusColor = Colors.orange;
      statusBgColor = Colors.orange.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Status & Booking ID
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_filled_rounded, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                    children: [
                      const TextSpan(text: 'Booking ID  '),
                      TextSpan(
                        text: '#${bookingId.length > 6 ? bookingId.substring(0, 6) : bookingId}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imagePath.startsWith('http')
                      ? Image.network(
                          imagePath,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        )
                      : Image.asset(
                          imagePath,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 16),
                // Text Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildIconLabel(Icons.calendar_today_rounded, date, textSecondary),
                      const SizedBox(height: 6),
                      _buildIconLabel(Icons.access_time_rounded, time, textSecondary),
                      const SizedBox(height: 6),
                      _buildIconLabel(Icons.location_on_rounded, address, textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer Row: Amount & View Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Amount Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Amount', style: TextStyle(color: textSecondary, fontSize: 10)),
                          Text(
                            amount,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // View Details Button
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingDetailScreen(
                          bookingData: booking,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    backgroundColor: const Color(0xFFF9FAFB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: primaryColor, size: 18),
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

  Widget _buildIconLabel(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF2029C5).withOpacity(0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
