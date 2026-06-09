import 'package:flutter/material.dart';
import 'package:car_washing_service_app/features/home/providers/bookmark_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_detail_screen.dart';
import 'package:car_washing_service_app/features/home/widgets/service_rating_row.dart';
import '../models/service_model.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const backgroundColor = Color(0xFFF8F9FE);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
        centerTitle: true,
        title: const Text(
          'My Bookmarks',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ref.watch(bookmarksProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (bookmarks) => bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text(
                    'No bookmarks yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Save your favorite services here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
                double childAspectRatio = constraints.maxWidth > 700 ? 0.95 : 0.85;

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmarkData = bookmarks[index];
                    // Construct a partial ServiceModel from bookmark data
                    final service = ServiceModel(
                      id: '',
                      name: bookmarkData['title'] ?? '',
                      image: bookmarkData['imagePath'] ?? '',
                      category: '',
                      categoryId: bookmarkData['categoryId'] ?? '',
                      price: bookmarkData['price']?.toString() ?? '0',
                      oldPrice: bookmarkData['oldPrice']?.toString() ?? '',
                      shortDescription: 'Professional cleaning service using premium products.',
                      longDescription: '',
                      status: 'Active',
                      whatsIncluded: [],
                      whatsNotIncluded: [],
                    );
                    return _buildBookmarkCard(context, service, bookmarkData, index, primaryColor, textPrimary, textSecondary);
                  },
                );
              },
            ),
      ),
    );
  }

  Widget _buildBookmarkCard(
    BuildContext context, 
    ServiceModel service,
    Map<String, dynamic> rawData,
    int index,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: service.image.startsWith('http')
                  ? Image.network(
                      service.image,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ),
                    )
                  : Image.asset(
                      service.image,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
              ),
              Positioned(
                top: 15,
                right: 15,
                child: GestureDetector(
                  onTap: () async {
                    await BookmarkService.toggleBookmark(rawData);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bookmark, color: Color(0xFF2029C5), size: 18),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '₹${service.price}',
                      style: const TextStyle(
                        color: Color(0xFF2029C5),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ServiceRatingRow(serviceName: service.name),
                const SizedBox(height: 8),
                Text(
                  service.shortDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ServiceDetailScreen(
                            service: service,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2029C5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
