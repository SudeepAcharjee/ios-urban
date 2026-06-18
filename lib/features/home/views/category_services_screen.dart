import 'package:car_washing_service_app/features/home/views/service_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/service_provider.dart';
import '../models/service_model.dart';
import '../widgets/service_rating_row.dart';
import '../viewmodels/category_provider.dart';
import 'package:car_washing_service_app/core/providers/mode_provider.dart';
import 'package:toastification/toastification.dart';
import 'package:car_washing_service_app/features/home/providers/bookmark_provider.dart';

class CategoryServicesScreen extends ConsumerWidget {
  final String categoryName;
  const CategoryServicesScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF2029C5);
    const backgroundColor = Color(0xFFF8F9FE);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    final isOffline = ref.watch(modeProvider).value ?? false;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ),
        centerTitle: true,
        title: Text(
          '$categoryName Services',
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ref.watch(servicesByCategoryProvider(categoryName)).when(
        data: (services) => services.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'images/icons/icon-1.png',
                      width: 70,
                      height: 70,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No services available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We are working on adding exciting $categoryName services for you. Stay tuned!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: services.length,
                separatorBuilder: (context, index) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _buildServiceCard(
                    context,
                    service: service,
                    primaryColor: primaryColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    ref: ref,
                    isOffline: isOffline,
                  );
                },
              ),
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: 4,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) => _buildSkeletonCard(context),
        ),
        error: (e, st) => Center(child: Text('Error loading services: $e')),
      ),
    );
  }

  Widget _buildSkeletonContainer({
    required double height,
    required double width,
    required double borderRadius,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade100,
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonContainer(height: 180, width: double.infinity, borderRadius: 20),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSkeletonContainer(height: 12, width: 60, borderRadius: 4),
                    _buildSkeletonContainer(height: 12, width: 50, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSkeletonContainer(height: 14, width: 100, borderRadius: 4),
                const SizedBox(height: 12),
                _buildSkeletonContainer(height: 18, width: 180, borderRadius: 4),
                const SizedBox(height: 8),
                _buildSkeletonContainer(height: 12, width: 220, borderRadius: 4),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSkeletonContainer(height: 25, width: 80, borderRadius: 4),
                    _buildSkeletonContainer(height: 40, width: 90, borderRadius: 25),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildServiceCard(
    BuildContext context, {
    required ServiceModel service,
    required Color primaryColor,
    required Color textPrimary,
    required Color textSecondary,
    required WidgetRef ref,
    required bool isOffline,
  }) {
    final isBookmarked = ref.watch(bookmarksProvider).maybeWhen(
      data: (bookmarks) => bookmarks.any((s) => s['title'] == service.name),
      orElse: () => false,
    );

    String discountStr = '';
    if (service.oldPrice.isNotEmpty) {
      final oldP = double.tryParse(service.oldPrice) ?? 0;
      final currP = double.tryParse(service.price) ?? 0;
      if (oldP > currP && oldP > 0) {
        final discount = ((oldP - currP) / oldP * 100).round();
        discountStr = '$discount% OFF';
      }
    }

    return GestureDetector(
      onTap: () {
        final categories = ref.read(categoriesProvider).value ?? [];
        final currentCategory = categories.firstWhere(
          (c) => c.name.toLowerCase() == service.category.toLowerCase(),
          orElse: () => CategoryModel(id: '', name: '', iconUrl: '', fallbackIcon: Icons.category, status: 'active'),
        );

        if (service.status.toLowerCase() == 'inactive' || 
            service.status.toLowerCase() == 'deactivated') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2029C5)),
                  const SizedBox(width: 10),
                  const Text('Service Unavailable'),
                ],
              ),
              content: Text(
                'The "${service.name}" service is temporarily unavailable. Please check back later!',
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
          return;
        }

        if (currentCategory.status.toLowerCase() == 'inactive' || 
            currentCategory.status.toLowerCase() == 'deactivated') {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2029C5)),
                  const SizedBox(width: 10),
                  const Text('Category Unavailable'),
                ],
              ),
              content: Text(
                'This service is temporarily unavailable because the "${service.category}" category is deactivated for maintenance.',
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
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceDetailScreen(service: service),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Image Header)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Full-width Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: service.image.startsWith('http')
                        ? Image.network(service.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200))
                        : Image.asset(service.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200)),
                  ),
                  
                  // Top Left Discount Tag
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
                            const Icon(Icons.check, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              discountStr,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Top Right Favorite Icon
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () async {
                        final cardData = {
                          'title': service.name,
                           'imagePath': service.image,
                           'price': int.tryParse(service.price) ?? 0,
                           'oldPrice': int.tryParse(service.oldPrice) ?? 0,
                        };
                        await BookmarkService.toggleBookmark(cardData);
                        
                        if (!context.mounted) return;
                        toastification.show(
                          context: context,
                          type: isBookmarked ? ToastificationType.info : ToastificationType.success,
                          style: ToastificationStyle.flatColored,
                          title: Text(isBookmarked ? 'Removed from Bookmarks' : 'Saved to Bookmarks'),
                          autoCloseDuration: const Duration(seconds: 2),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Icon(
                          isBookmarked ? Icons.favorite : Icons.favorite_border,
                          color: isBookmarked ? Colors.red : Colors.grey,
                          size: 20,
                        ),
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
                  // Rating Row
                  ServiceRatingRow(serviceName: service.name),
                  
                  const SizedBox(height: 10),
                  
                  // Title
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Short Description
                  Text(
                    service.shortDescription.isNotEmpty ? service.shortDescription : 'Complete cleaning with foam wash, polishing, chain cleaning & premium finishing.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bottom Actions (Price Box & View Button)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9), // Light green background
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD1FAE5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${service.price}',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (service.oldPrice.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '₹${service.oldPrice}',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (discountStr.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  discountStr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // View Button (Pill-shaped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB), // Sleek blue
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.chevron_right, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ],
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
