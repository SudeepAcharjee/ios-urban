import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discount_provider.dart';
import '../models/discount_model.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountsAsync = ref.watch(discountProvider);

    // List of premium colors for the cards if not provided in DB
    final List<Color> themeColors = [
      const Color(0xFF2029C5), // Purple
      const Color(0xFFDC2626), // Red
      const Color(0xFF059669), // Green
      const Color(0xFF7C3AED), // Violet
      const Color(0xFFEA580C), // Orange
    ];

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
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF111827)),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Offers & Rewards',
          style: TextStyle(
            color: Color(0xFF111827), 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: discountsAsync.when(
          data: (discounts) {
            final activeDiscounts = discounts.where((d) => d.status == 'active' && !d.isExpired).toList();
            
            if (activeDiscounts.isEmpty) {
              return const Center(
                child: Text(
                  'No offers available right now',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: activeDiscounts.length,
              itemBuilder: (context, index) {
                final discount = activeDiscounts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildPremiumOfferCard(
                    context,
                    discount: discount,
                    themeColor: themeColors[index % themeColors.length],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildPremiumOfferCard(
    BuildContext context, {
    required DiscountModel discount,
    required Color themeColor,
  }) {
    return Container(
      width: double.infinity,
      height: 180,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 🖼️ Full Background Image
          Positioned.fill(
            child: discount.imageUrl.isNotEmpty
                ? Image.network(
                    discount.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: themeColor.withOpacity(0.3),
                      child: const Icon(Icons.broken_image, color: Colors.white24, size: 50),
                    ),
                  )
                : Container(color: themeColor.withOpacity(0.5)),
          ),
          
          // 🌑 Smooth Horizontal Colored Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.6, 1.0],
                ),
              ),
            ),
          ),
          
          // 📝 Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Ends ${discount.endDate}',
                    style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  discount.displayTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      discount.displaySubtitle,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    if (discount.type == 'percentage')
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                        child: const Icon(Icons.percent, size: 10, color: Colors.white),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  discount.displayFooter,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9), 
                    fontSize: 12, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 🔘 Claim Button
          Positioned(
            right: 20,
            bottom: 20,
            child: ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: discount.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Promo code "${discount.code}" copied!'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: themeColor,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                elevation: 0,
              ),
              child: const Text('Claim', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
