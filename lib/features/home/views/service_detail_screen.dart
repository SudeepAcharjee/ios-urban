import 'package:car_washing_service_app/features/home/views/book_a_wash_screen.dart';

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:car_washing_service_app/features/home/providers/bookmark_provider.dart';
import 'package:car_washing_service_app/features/home/providers/review_provider.dart';
import 'package:car_washing_service_app/features/home/models/review_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/service_model.dart';
import '../viewmodels/category_provider.dart';
import 'package:car_washing_service_app/core/providers/mode_provider.dart';

class ServiceDetailScreen extends ConsumerStatefulWidget {
  final ServiceModel service;
  final String providerName;
  final String providerRole;

  const ServiceDetailScreen({
    super.key,
    required this.service,
    this.providerName = 'Expert Team',
    this.providerRole = 'Service Provider',
  });

  @override
  ConsumerState<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const accentBlue = Color(0xFFE8EAF6);
    ref.watch(modeProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ⚪ Status Bar Background
          Container(
            height: MediaQuery.of(context).padding.top,
            color: Colors.white,
          ),
          Expanded(
            child: Stack(
              children: [
                // 📜 Main Scrollable Content
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Image Header with Overlays
                Stack(
                  children: [
                    Hero(
                      tag: 'service_image_${widget.service.id}',
                      child: widget.service.image.startsWith('http')
                          ? Image.network(
                              widget.service.image,
                              width: double.infinity,
                              height: 440,
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              widget.service.image,
                              width: double.infinity,
                              height: 440,
                              fit: BoxFit.cover,
                            ),
                    ),
                    // Gradient Overlay for readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ⬅️ Back Button
                    Positioned(
                      top: 16,
                      left: 20,
                      child: _buildCircularButton(
                        icon: Icons.arrow_back_ios_new,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // ❤️ Favorite Button
                    Positioned(
                      top: 16,
                      right: 20,
                      child: _buildCircularButton(
                        icon: ref.watch(bookmarksProvider).maybeWhen(
                              data: (bookmarks) => bookmarks.any((s) => s['title'] == widget.service.name),
                              orElse: () => false,
                            )
                            ? Icons.favorite
                            : Icons.favorite_border,
                        iconColor: ref.watch(bookmarksProvider).maybeWhen(
                              data: (bookmarks) => bookmarks.any((s) => s['title'] == widget.service.name),
                              orElse: () => false,
                            ) ? Colors.red : textPrimary,
                        onPressed: () => _handleToggleBookmark(),
                      ),
                    ),
                    // ✅ Verified Service Badge
                    Positioned(
                      bottom: 50,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 12),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Verified Service',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 📄 Content Card
                Transform.translate(
                  offset: const Offset(0, -35),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(25, 30, 25, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ⭐ Rating Row
                          ref.watch(reviewsProvider(widget.service.name)).when(
                            data: (reviews) {
                              double displayRating = 0.0;
                              if (reviews.isNotEmpty) {
                                displayRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
                              }
                              return Row(
                                children: [
                                  Row(
                                    children: List.generate(5, (index) => Icon(
                                      Icons.star, 
                                      color: index < displayRating.floor() ? Colors.amber : Colors.grey.shade300, 
                                      size: 20
                                    )),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    displayRating.toStringAsFixed(1),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '(${reviews.length} Reviews)',
                                    style: const TextStyle(color: textSecondary, fontSize: 14),
                                  ),
                                ],
                              );
                            },
                            loading: () => Row(
                              children: [
                                Row(
                                  children: List.generate(5, (index) => Icon(Icons.star, color: Colors.grey.shade300, size: 20)),
                                ),
                                const SizedBox(width: 10),
                                const Text('...', style: TextStyle(color: textSecondary)),
                              ],
                            ),
                            error: (_, __) => Row(
                              children: [
                                Row(
                                  children: List.generate(5, (index) => Icon(
                                    Icons.star, 
                                    color: index < widget.service.rating.floor() ? Colors.amber : Colors.grey.shade300, 
                                    size: 20
                                  )),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  widget.service.rating.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '(${widget.service.reviews} Reviews)',
                                  style: const TextStyle(color: textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // 🏷️ Title
                          Text(
                            widget.service.name,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // 💰 Pricing & Time Row
                          Row(
                            children: [
                              Text(
                                '₹${widget.service.price}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (widget.service.oldPrice.isNotEmpty)
                                Text(
                                  '₹${widget.service.oldPrice}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: textSecondary.withOpacity(0.5),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: accentBlue,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_filled, size: 18, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.service.serviceTime,
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // 📖 About Section
                          const Text(
                            'About Service',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.service.longDescription.isNotEmpty 
                              ? widget.service.longDescription 
                              : widget.service.shortDescription,
                            style: const TextStyle(color: textSecondary, height: 1.6, fontSize: 15),
                          ),

                          const SizedBox(height: 30),

                          // 🛠️ Features Grid
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildFeatureItem(Icons.water_drop_outlined, 'Foam Wash', 'Included'),
                                _buildVerticalDivider(),
                                _buildFeatureItem(Icons.auto_awesome_outlined, 'Polishing', 'Included'),
                                _buildVerticalDivider(),
                                _buildFeatureItem(Icons.eco_outlined, 'Water Saving', 'Eco Friendly'),
                                _buildVerticalDivider(),
                                _buildFeatureItem(Icons.verified_user_outlined, 'Service Type', 'Premium'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ✅ What's Included Section
                          if (widget.service.whatsIncluded.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('What\'s Included', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                          Text('This service includes the following', style: TextStyle(fontSize: 12, color: Color(0xFF047857))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ...widget.service.whatsIncluded.map((item) => _buildIncludedItem(item, primaryColor)).toList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ❌ What's NOT Included Section
                          if (widget.service.whatsNotIncluded.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('What\'s NOT Included', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                          Text('Not part of this service', style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  ...widget.service.whatsNotIncluded.map((item) => _buildExcludedItem(item)).toList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                          
                          // ⭐ Reviews Header & Overview
                          const Text(
                            'Customer Reviews',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          const SizedBox(height: 15),
                          
                          ref.watch(reviewsProvider(widget.service.name)).when(
                            data: (reviews) => Column(
                              children: [
                                if (reviews.isNotEmpty) ...[
                                  _buildRatingOverview(reviews),
                                  const SizedBox(height: 20),
                                ],
                                _buildSimplifiedReviews(),
                              ],
                            ),
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (_, __) => const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🛍️ Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 15, 20, MediaQuery.of(context).padding.bottom + 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _navigateToBooking(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Book Now',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_outlined, size: 14, color: textSecondary),
                      const SizedBox(width: 5),
                      const Text(
                        'Secure Booking',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 15),
                      const Text('•', style: TextStyle(color: textSecondary)),
                      const SizedBox(width: 15),
                      const Text(
                        '100% Satisfaction',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    ],
    ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onPressed, Color? iconColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? const Color(0xFF111827), size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2029C5), size: 26),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2029C5)),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade200,
    );
  }

  void _handleToggleBookmark() async {
    final cardData = {
      'title': widget.service.name,
      'imagePath': widget.service.image,
      'price': int.tryParse(widget.service.price) ?? 0,
      'oldPrice': int.tryParse(widget.service.oldPrice) ?? 0,
    };
    
    final isCurrentlyBookmarked = ref.read(bookmarksProvider).maybeWhen(
      data: (bookmarks) => bookmarks.any((s) => s['title'] == widget.service.name),
      orElse: () => false,
    );

    await BookmarkService.toggleBookmark(cardData);
    
    if (mounted) {
      toastification.show(
        context: context,
        type: isCurrentlyBookmarked ? ToastificationType.info : ToastificationType.success,
        style: ToastificationStyle.flatColored,
        title: Text(isCurrentlyBookmarked ? 'Removed from Bookmarks' : 'Saved to Bookmarks'),
        autoCloseDuration: const Duration(seconds: 2),
      );
    }
  }

  void _navigateToBooking() {
    final isOffline = ref.read(modeProvider).value ?? false;
    if (isOffline) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              const Text('App is Offline'),
            ],
          ),
          content: const Text(
            'We are currently undergoing offline maintenance and not accepting new bookings. Please try again later!',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
            ),
          ],
        ),
      );
      return;
    }

    final categories = ref.read(categoriesProvider).value ?? [];
    final currentCategory = categories.firstWhere(
      (c) => c.name.toLowerCase() == widget.service.category.toLowerCase(),
      orElse: () => CategoryModel(id: '', name: '', iconUrl: '', fallbackIcon: Icons.category, status: 'active'),
    );

    if (currentCategory.status.toLowerCase() == 'inactive' || 
        currentCategory.status.toLowerCase() == 'deactivated') {
      _showUnavailableDialog();
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => BookAWashScreen(
      imagePath: widget.service.image, 
      title: widget.service.name, 
      price: int.tryParse(widget.service.price) ?? 0,
      serviceId: widget.service.id,
      categoryId: widget.service.categoryId,
      categoryName: widget.service.category, 
    )));
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF2029C5)),
            SizedBox(width: 10),
            Text('Service Unavailable'),
          ],
        ),
        content: Text(
          'This service is temporarily unavailable because the "${widget.service.category}" category is deactivated for maintenance.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedReviews() {
    return ref.watch(reviewsProvider(widget.service.name)).when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 80, color: const Color(0xFF2029C5).withOpacity(0.1)),
                    const Icon(Icons.more_horiz, size: 30, color: Color(0xFF2029C5)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'No reviews yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Be the first one to review this service',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          );
        }
        return Column(
          children: reviews.take(2).map((review) => _buildReviewItem(review, const Color(0xFF2029C5), const Color(0xFF6B7280))).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildReviewItem(ReviewModel review, Color primaryColor, Color textSecondary) {
    final String formattedDate = DateFormat('dd MMM yyyy').format(review.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
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
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: review.userAvatar.isNotEmpty ? NetworkImage(review.userAvatar) : null,
                child: review.userAvatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) => Icon(
                        Icons.star, 
                        color: index < review.rating ? Colors.amber : Colors.grey.shade300, 
                        size: 14,
                      )),
                    ),
                  ],
                ),
              ),
              Text(formattedDate, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(color: Color(0xFF4B5563), height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedItem(String title, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRatingOverview(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return const SizedBox();

    int totalReviews = reviews.length;
    double avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews;
    
    Map<int, int> ratingCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var review in reviews) {
      int r = review.rating.round().clamp(1, 5);
      ratingCounts[r] = (ratingCounts[r] ?? 0) + 1;
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Average Rating
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    double starValue = avgRating - index;
                    IconData iconData;
                    if (starValue >= 0.8) {
                      iconData = Icons.star;
                    } else if (starValue >= 0.3) {
                      iconData = Icons.star_half;
                    } else {
                      iconData = Icons.star_border;
                    }
                    return Icon(iconData, color: Colors.amber, size: 20);
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  '($totalReviews Reviews)',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 20),
          
          // Right side: Progress bars
          Expanded(
            flex: 3,
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                double percent = totalReviews > 0 ? (ratingCounts[star]! / totalReviews) : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ratingCounts[star]}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryImageCard extends StatefulWidget {
  final String imageUrl;
  final Widget Function({
    required double height,
    required double width,
    required double borderRadius,
  }) skeleton;

  const GalleryImageCard({
    super.key,
    required this.imageUrl,
    required this.skeleton,
  });

  @override
  State<GalleryImageCard> createState() => _GalleryImageCardState();
}

class _GalleryImageCardState extends State<GalleryImageCard> {
  bool _isLoaded = false;
  late ImageProvider _imageProvider;

  @override
  void initState() {
    super.initState();
    _imageProvider = NetworkImage(widget.imageUrl);
    _imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (info, synchronousCall) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onError: (exception, stackTrace) {
          if (mounted) setState(() => _isLoaded = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            if (!_isLoaded)
              Positioned.fill(
                child: widget.skeleton(
                  height: 120,
                  width: 160,
                  borderRadius: 15,
                ),
              ),
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isLoaded ? 1.0 : 0.0,
                child: Image(
                  image: _imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
