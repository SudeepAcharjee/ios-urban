import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/custom_toast.dart';
import '../../auth/views/login_screen.dart';
import 'shop_onboarding_screen.dart';
import 'shop_waiting_approval_screen.dart';
import 'shop_add_service_screen.dart';
import 'shop_edit_service_screen.dart';
import 'shop_payment_details_screen.dart';
import 'shop_profile_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'shop_booking_detail_screen.dart';
import 'shop_bookings_screen.dart';
import 'shop_notifications_screen.dart';

class ShopMainScreen extends ConsumerStatefulWidget {
  const ShopMainScreen({super.key});

  @override
  ConsumerState<ShopMainScreen> createState() => _ShopMainScreenState();
}

class _ShopMainScreenState extends ConsumerState<ShopMainScreen> {
  static const primaryColor = Color(0xFF2029C5);
  int _currentTabIndex = 0;


  void _confirmDeleteService(
    BuildContext context,
    String docId,
    String collectionName,
    String serviceName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Delete Service', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$serviceName"? This service will be permanently removed.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete from specified collection
                await FirebaseFirestore.instance.collection(collectionName).doc(docId).delete();

                // If deleting an approved service, also clean up matching verify-service record
                if (collectionName == 'services') {
                  final vDocs = await FirebaseFirestore.instance
                      .collection('verify-service')
                      .where('serviceId', isEqualTo: docId)
                      .get();
                  for (final d in vDocs.docs) {
                    await d.reference.delete();
                  }
                }

                if (context.mounted) {
                  CustomToast.success(context, 'Service "$serviceName" deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  CustomToast.error(context, 'Failed to delete service: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showServiceDetailModal(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
    String collectionName, {
    required bool isPending,
    String? rejectionReason,
  }) {
    final String name = (data['name'] ?? 'Service').toString();
    final String image = (data['image'] ?? '').toString();
    final String category = (data['category'] ?? '').toString();
    final String price = (data['price'] ?? '0').toString();
    final String oldPrice = (data['oldPrice'] ?? '').toString();
    final String shortDesc = (data['shortDescription'] ?? '').toString();
    final String longDesc = (data['longDescription'] ?? '').toString();
    final String serviceTime = (data['serviceTime'] ?? '30–45 mins').toString();
    final String address = (data['address'] ?? '').toString();
    final dynamic lat = data['latitude'];
    final dynamic lng = data['longitude'];
    final dynamic radius = data['radius'];
    final List<dynamic> gallery = (data['gallery'] is List) ? data['gallery'] : [];
    final List<dynamic> whatsIncluded = (data['whatsIncluded'] is List) ? data['whatsIncluded'] : [];
    final List<dynamic> whatsNotIncluded = (data['whatsNotIncluded'] is List) ? data['whatsNotIncluded'] : [];
    final String status = (data['status'] ?? (isPending ? 'Pending' : 'Active')).toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      children: [
                        if (image.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              image,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(height: 120, color: Colors.grey.shade100),
                            ),
                          ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category.isNotEmpty ? category : 'Workshop',
                                style: const TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? (status.toLowerCase() == 'rejected' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7))
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPending
                                    ? (status.toLowerCase() == 'rejected' ? 'REJECTED' : 'PENDING APPROVAL')
                                    : 'ACTIVE',
                                style: TextStyle(
                                  color: isPending
                                      ? (status.toLowerCase() == 'rejected' ? Colors.red.shade800 : Colors.amber.shade900)
                                      : Colors.green.shade800,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PRICE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text('₹$price', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                      if (oldPrice.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text('₹$oldPrice', style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              Container(height: 30, width: 1, color: Colors.grey.shade300),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('DURATION', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(serviceTime, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                ],
                              ),
                              if (radius != null) ...[
                                Container(height: 30, width: 1, color: Colors.grey.shade300),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('RADIUS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('$radius KM', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        if (shortDesc.isNotEmpty) ...[
                          const Text('Overview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 6),
                          Text(shortDesc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
                          const SizedBox(height: 16),
                        ],

                        if (longDesc.isNotEmpty) ...[
                          const Text('Detailed Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 6),
                          Text(longDesc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
                          const SizedBox(height: 16),
                        ],

                        if (whatsIncluded.isNotEmpty) ...[
                          const Text('What\'s Included', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          const SizedBox(height: 8),
                          ...whatsIncluded.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],

                        if (whatsNotIncluded.isNotEmpty) ...[
                          const Text('What\'s NOT Included', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                          const SizedBox(height: 8),
                          ...whatsNotIncluded.map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item.toString(), style: const TextStyle(fontSize: 13))),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],

                        if (address.isNotEmpty) ...[
                          const Text('Service Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: primaryColor, size: 18),
                              const SizedBox(width: 6),
                              Expanded(child: Text(address, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                            ],
                          ),
                          if (lat != null && lng != null) ...[
                            const SizedBox(height: 4),
                            Text('Coordinates: $lat, $lng', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                          const SizedBox(height: 16),
                        ],

                        if (gallery.isNotEmpty) ...[
                          const Text('Service Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: gallery.length,
                              itemBuilder: (context, idx) {
                                return Container(
                                  width: 90,
                                  height: 90,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.network(gallery[idx].toString(), fit: BoxFit.cover),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),

                  SafeArea(
                    top: false,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        14 + (MediaQuery.of(context).viewPadding.bottom > 0 ? MediaQuery.of(context).viewPadding.bottom : 18),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmDeleteService(context, docId, collectionName, name);
                              },
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ShopEditServiceScreen(
                                      docId: docId,
                                      collectionName: collectionName,
                                      initialData: data,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit Service', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildServiceCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId, {
    required bool isPending,
    String? rejectionReason,
  }) {
    final String name = (data['name'] ?? 'Service').toString();
    final String image = (data['image'] ?? '').toString();
    final String category = (data['category'] ?? '').toString();
    final String price = (data['price'] ?? '0').toString();
    final String oldPrice = (data['oldPrice'] ?? '').toString();
    final String shortDesc = (data['shortDescription'] ?? '').toString();
    final String serviceTime = (data['serviceTime'] ?? '30–45 mins').toString();
    final String status = (data['status'] ?? (isPending ? 'Pending' : 'Active')).toString();
    final String collectionName = isPending ? 'verify-service' : 'services';

    String discountStr = '';
    final numPrice = double.tryParse(price);
    final numOld = double.tryParse(oldPrice);
    if (numPrice != null && numOld != null && numOld > numPrice) {
      final pct = (((numOld - numPrice) / numOld) * 100).round();
      if (pct > 0) discountStr = '$pct% OFF';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showServiceDetailModal(
            context,
            data,
            docId,
            collectionName,
            isPending: isPending,
            rejectionReason: rejectionReason,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image Header
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: image.isNotEmpty
                          ? Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                              ),
                            )
                          : Container(
                              color: primaryColor.withOpacity(0.08),
                              child: const Center(child: Icon(Icons.storefront_rounded, size: 50, color: primaryColor)),
                            ),
                    ),

                    if (discountStr.isNotEmpty)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer_rounded, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                discountStr,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isPending
                              ? (status.toLowerCase() == 'rejected' ? const Color(0xFFDC2626) : const Color(0xFFD97706))
                              : const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPending
                                  ? (status.toLowerCase() == 'rejected' ? Icons.cancel_rounded : Icons.hourglass_top_rounded)
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isPending
                                  ? (status.toLowerCase() == 'rejected' ? 'REJECTED' : 'PENDING APPROVAL')
                                  : 'ACTIVE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Info Content Section
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category.isNotEmpty ? category : 'Workshop',
                            style: const TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          serviceTime,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    Text(
                      shortDesc.isNotEmpty ? shortDesc : 'Complete servicing with high quality tools and certified inspection.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Reason: $rejectionReason',
                                style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Bottom Pricing & Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD1FAE5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹$price',
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              if (oldPrice.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '₹$oldPrice',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Action Buttons: View, Edit, Delete
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View Button
                            IconButton(
                              onPressed: () => _showServiceDetailModal(
                                context,
                                data,
                                docId,
                                collectionName,
                                isPending: isPending,
                                rejectionReason: rejectionReason,
                              ),
                              tooltip: 'View Details',
                              icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Edit Button
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ShopEditServiceScreen(
                                      docId: docId,
                                      collectionName: collectionName,
                                      initialData: data,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Edit Service',
                              icon: const Icon(Icons.edit_outlined, size: 18, color: primaryColor),
                              style: IconButton.styleFrom(
                                backgroundColor: primaryColor.withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Delete Button
                            IconButton(
                              onPressed: () => _confirmDeleteService(
                                context,
                                docId,
                                collectionName,
                                name,
                              ),
                              tooltip: 'Delete Service',
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade600),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shops').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        final shopData = snapshot.data?.data() ?? {};
        final status = (shopData['status'] ?? 'pending').toString().toLowerCase();
        final bool onboardingCompleted = shopData['onboardingCompleted'] == true;

        // If onboarding is incomplete, enforce onboarding screen
        if (!onboardingCompleted) {
          return ShopOnboardingScreen(initialShopData: shopData);
        }

        // Strictly enforce approval: do not hide waiting approval screen until admin approves!
        if (status != 'active' && status != 'approved') {
          return const ShopWaitingApprovalScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: false,
            titleSpacing: 16,
            title: Image.asset(
              'images/logo/Urban Services.png',
              height: 32,
              fit: BoxFit.contain,
            ),
            actions: [
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instanceFor(
                  app: Firebase.app(),
                  databaseURL:
                      'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
                ).ref('notifications/${user.uid}').onValue,
                builder: (context, notifSnap) {
                  int unreadCount = 0;
                  if (notifSnap.hasData && notifSnap.data?.snapshot.value != null) {
                    final dynamic raw = notifSnap.data!.snapshot.value;
                    if (raw is Map) {
                      raw.forEach((key, val) {
                        if (val is Map && val['isRead'] != true) {
                          unreadCount++;
                        }
                      });
                    }
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ShopNotificationsScreen(),
                              ),
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Color(0xFF0F172A),
                              size: 20,
                            ),
                          ),
                          tooltip: 'Notifications',
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildManageTab(context, shopData, user.uid),
              const ShopBookingsScreen(showBackButton: false),
              _buildServicesTab(context, shopData, user.uid),
              const ShopPaymentDetailsScreen(showBackButton: false),
              const ShopProfileScreen(showBackButton: false),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentTabIndex,
              onTap: (index) => setState(() => _currentTabIndex = index),
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded, color: primaryColor),
                  label: 'Manage',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month_rounded, color: primaryColor),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_repair_service_outlined),
                  activeIcon: Icon(Icons.home_repair_service_rounded, color: primaryColor),
                  label: 'Services',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet_rounded, color: primaryColor),
                  label: 'Payments',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded, color: primaryColor),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 0: MANAGE
  // -------------------------------------------------------------
  Widget _buildManageTab(BuildContext context, Map<String, dynamic> shopData, String uid) {
    final shopName = (shopData['shopName'] ?? shopData['businessName'] ?? 'Workshop').toString();
    final serviceType = (shopData['serviceType'] ?? 'Car & Bike Servicing').toString();
    final address = (shopData['address'] ?? shopData['shopAddress'] ?? 'Location not set').toString();
    final String? shopPhoto = (shopData['shopPhoto'] ??
            shopData['profilePic'] ??
            shopData['shopImage'] ??
            shopData['image'] ??
            shopData['imageUrl'])
        ?.toString();
    final bool isOpen = shopData['isOpen'] ?? true;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, activeSnap) {
        final activeDocs = activeSnap.data?.docs ?? [];
        final activeServiceIds = activeDocs.map((d) => d.id).toSet();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('verify-service')
              .where('ownerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, verifySnap) {
            final pendingDocs = (verifySnap.data?.docs ?? []).where((doc) {
              final s = (doc.data()['status'] ?? 'pending').toString().toLowerCase();
              if (s == 'approved') return false;
              final serviceId = doc.data()['serviceId'];
              final name = (doc.data()['name'] ?? '').toString().trim().toLowerCase();
              final isAlreadyActive = activeDocs.any((aDoc) {
                if (serviceId != null && aDoc.id == serviceId) return true;
                return (aDoc.data()['name'] ?? '').toString().trim().toLowerCase() == name;
              });
              return !isAlreadyActive;
            }).toList();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .snapshots(),
              builder: (context, bookingsSnap) {
                final allBookings = bookingsSnap.data?.docs ?? [];
                
                // Filter bookings for this shop
                final shopBookings = allBookings.where((doc) {
                  final data = doc.data();
                  final bShopId = data['shopId']?.toString();
                  final bOwnerId = data['ownerId']?.toString();
                  final bServiceId = data['serviceId']?.toString();
                  return bShopId == uid ||
                      bOwnerId == uid ||
                      (bServiceId != null && activeServiceIds.contains(bServiceId));
                }).toList();

                // Sort by createdAt descending
                shopBookings.sort((a, b) {
                  final aTime = (a.data()['createdAt'] is Timestamp)
                      ? (a.data()['createdAt'] as Timestamp).toDate()
                      : DateTime(2000);
                  final bTime = (b.data()['createdAt'] is Timestamp)
                      ? (b.data()['createdAt'] as Timestamp).toDate()
                      : DateTime(2000);
                  return bTime.compareTo(aTime);
                });

                final totalBookings = shopBookings.length;
                final activeOrders = shopBookings.where((doc) {
                  final st = (doc.data()['status'] ?? '').toString().toLowerCase();
                  return st == 'pending' ||
                      st == 'confirmed' ||
                      st == 'assigned' ||
                      st == 'in progress' ||
                      st == 'in-progress';
                }).length;


                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. WORKSHOP HERO & STATUS CARD
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              primaryColor,
                              Color(0xFF3B82F6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              // Subtle decorative circles
                              Positioned(
                                right: -40,
                                top: -30,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 30,
                                bottom: -40,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),

                              // Card Content
                              Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(11),
                                            child: (shopPhoto != null && shopPhoto.isNotEmpty)
                                                ? Image.network(
                                                    shopPhoto,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Icon(
                                                      Icons.storefront_rounded,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.storefront_rounded,
                                                    color: Colors.white,
                                                    size: 24,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                shopName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                serviceType,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (address.isNotEmpty && address != 'Location not set') ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on_outlined,
                                                      size: 12,
                                                      color: Colors.white.withValues(alpha: 0.8),
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        address,
                                                        style: TextStyle(
                                                          color: Colors.white.withValues(alpha: 0.8),
                                                          fontSize: 11,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  color: isOpen ? const Color(0xFF10B981) : Colors.redAccent,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (isOpen ? const Color(0xFF10B981) : Colors.redAccent)
                                                          .withValues(alpha: 0.6),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isOpen ? 'Accepting Orders' : 'Shop Closed',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    isOpen ? 'Visible to nearby customers' : 'Not receiving new bookings',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.75),
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Transform.scale(
                                            scale: 0.85,
                                            child: Switch.adaptive(
                                              value: isOpen,
                                              activeColor: const Color(0xFF10B981),
                                              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                                              onChanged: (val) => _toggleShopStatus(uid, isOpen),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 2. METRICS STATS GRID
                      const Text(
                        'Performance Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Total Bookings',
                              value: '$totalBookings',
                              icon: Icons.receipt_long_rounded,
                              iconColor: primaryColor,
                              bgColor: primaryColor.withOpacity(0.08),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Active Orders',
                              value: '$activeOrders',
                              icon: Icons.autorenew_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              bgColor: const Color(0xFFF59E0B).withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              title: 'Active Services',
                              value: '${activeDocs.length}',
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFF10B981).withOpacity(0.08),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricTile(
                              title: 'In Verification',
                              value: '${pendingDocs.length}',
                              icon: Icons.hourglass_top_rounded,
                              iconColor: const Color(0xFF6366F1),
                              bgColor: const Color(0xFF6366F1).withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. WORKSHOP BOOKINGS LIST
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Workshop Bookings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _currentTabIndex = 1);
                            },
                            tooltip: 'View All Bookings',
                            icon: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Bookings list (Up to 4 on home screen)
                      if (bookingsSnap.connectionState == ConnectionState.waiting) ...[
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: CircularProgressIndicator(color: primaryColor),
                          ),
                        ),
                      ] else if (shopBookings.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 38,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Bookings Yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When customers book your workshop services, they will appear here with live updates.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...shopBookings.take(4).map((doc) {
                          return _buildManageBookingCard(context, doc.id, doc.data());
                        }),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageBookingCard(BuildContext context, String bookingId, Map<String, dynamic> data) {
    final title = (data['title'] ?? data['serviceName'] ?? 'Service').toString();
    final customerName = (data['userName'] ?? data['customerName'] ?? 'Customer').toString();
    final price = (data['totalPrice'] ?? data['price'] ?? 0).toString();
    final status = (data['status'] ?? 'Pending').toString();
    final rawDate = data['date'] ?? data['bookingDate'];
    final timeSlot = data['time'] ?? data['timeSlot'] ?? '';
    final vehicleModel = data['carModel'] ?? data['vehicleName'] ?? data['vehicle'] ?? '';

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
                    if (vehicleModel.toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                      const SizedBox(width: 8),
                      Icon(Icons.directions_car_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        vehicleModel.toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (dateStr.isNotEmpty || timeSlot.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        [if (dateStr.isNotEmpty) dateStr, if (timeSlot.toString().isNotEmpty) timeSlot].join(' • '),
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

  Future<void> _toggleShopStatus(String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(uid).update({
        'isOpen': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        CustomToast.success(
          context,
          !currentStatus ? 'Workshop is now Accepting Bookings' : 'Workshop is now Closed',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to update status: $e');
      }
    }
  }

  // -------------------------------------------------------------
  // TAB 1: SERVICES
  // -------------------------------------------------------------
  Widget _buildServicesTab(BuildContext context, Map<String, dynamic> shopData, String uid) {
    final serviceType = shopData['serviceType'] ?? 'Car & Bike Servicing';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('verify-service')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, verifySnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('services')
              .where('ownerId', isEqualTo: uid)
              .snapshots(),
          builder: (context, activeSnap) {
            final activeDocs = activeSnap.data?.docs ?? [];
            final pendingDocs = (verifySnap.data?.docs ?? []).where((doc) {
              final s = (doc.data()['status'] ?? 'pending').toString().toLowerCase();
              if (s == 'approved') return false; // Approved services are already live in activeDocs!

              final serviceId = doc.data()['serviceId'];
              final name = (doc.data()['name'] ?? '').toString().trim().toLowerCase();
              final isAlreadyActive = activeDocs.any((aDoc) {
                if (serviceId != null && aDoc.id == serviceId) return true;
                return (aDoc.data()['name'] ?? '').toString().trim().toLowerCase() == name;
              });
              return !isAlreadyActive;
            }).toList();
            final totalCount = pendingDocs.length + activeDocs.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catalog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Workshop Services',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            '$totalCount services in catalog • $serviceType',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ShopAddServiceScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (verifySnap.connectionState == ConnectionState.waiting &&
                      activeSnap.connectionState == ConnectionState.waiting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    ),
                  ] else if (totalCount == 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.build_circle_outlined, size: 48, color: primaryColor),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Services Yet',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add your workshop services with photos, pricing, and coverage to get verified and start receiving bookings.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ShopAddServiceScreen()),
                              );
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Your First Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 1. Pending Verification Cards
                    ...pendingDocs.map((doc) {
                      final data = doc.data();
                      final reason = data['rejectionReason']?.toString();
                      return _buildServiceCard(context, data, doc.id, isPending: true, rejectionReason: reason);
                    }),

                    // 2. Active Verified Services Cards
                    ...activeDocs.map((doc) {
                      final data = doc.data();
                      return _buildServiceCard(context, data, doc.id, isPending: false);
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
