import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/discount_provider.dart';
import '../models/discount_model.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  final String? serviceName;
  final String? categoryName;
  final String? serviceId;
  final String? categoryId;

  const CouponsScreen({
    super.key,
    this.serviceName,
    this.categoryName,
    this.serviceId,
    this.categoryId,
  });

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final TextEditingController _couponController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const backgroundColor = Colors.white;
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    final discountsAsync = ref.watch(discountProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ),
        title: const Text(
          'Apply Coupon',
          style: TextStyle(
            color: textPrimary, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // 🎫 Enter Coupon Input
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _couponController,
                      decoration: const InputDecoration(
                        hintText: 'Enter Coupon Code',
                        hintStyle: TextStyle(color: textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_couponController.text.isNotEmpty) {
                        Navigator.pop(context, _couponController.text.toUpperCase());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 📜 Coupons List
          Expanded(
            child: discountsAsync.when(
              data: (discounts) {
                final currentUid = FirebaseAuth.instance.currentUser?.uid;

                final activeDiscounts = discounts.where((d) {
                  // Basic status check
                  if (d.status != 'active') return false;

                  // Expiration check
                  if (d.isExpired) return false;

                  // If coupon is tied to a specific user (referral reward), ensure it belongs to current user
                  if (d.userId != null && d.userId != currentUid) return false;

                  // Referral rewards apply to ANY booking
                  if (d.isReferralReward) return true;

                  // Filtering logic based on booking context
                  if (d.appliesTo == 'all') return true;

                  if (d.appliesTo == 'category') {
                    return d.categoryName == widget.categoryName;
                  }

                  if (d.appliesTo == 'service') {
                    return d.serviceName == widget.serviceName;
                  }

                  return false;
                }).toList();
                
                if (activeDiscounts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No coupons available right now',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Available Coupons',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textPrimary),
                    ),
                    const SizedBox(height: 15),
                    ...activeDiscounts.map((discount) => _buildCouponCard(
                      context,
                      discount,
                      primaryColor,
                    )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(
    BuildContext context,
    DiscountModel discount,
    Color primaryColor,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context, discount.code);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: discount.isReferralReward ? const Color(0xFFEFF6FF) : const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(16),
          border: discount.isReferralReward
              ? Border.all(color: const Color(0xFF93C5FD), width: 1.2)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Icon
            Icon(
              discount.isReferralReward ? Icons.card_giftcard_rounded : Icons.percent_rounded,
              color: discount.isReferralReward ? const Color(0xFF10B981) : primaryColor,
              size: 34,
            ),
            const SizedBox(width: 16),
            // Center: Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discount.isReferralReward)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🎁 Referral Reward • 10% OFF Any Booking',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  Text(
                    'Code: ${discount.code}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discount.displayTitle,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Valid till ${discount.endDate}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
