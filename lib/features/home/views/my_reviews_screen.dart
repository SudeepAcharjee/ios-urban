import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import '../viewmodels/booking_provider.dart';
import '../../worker/viewmodels/worker_provider.dart';

class MyReviewsScreen extends ConsumerWidget {
  final bool isWorker;
  const MyReviewsScreen({super.key, this.isWorker = false});

  Future<void> _deleteReview(BuildContext context, String reviewId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reviews').doc(reviewId).delete();
        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            title: const Text('Review Deleted'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Error'),
            description: Text(e.toString()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const textPrimary = Color(0xFF111827);
    final reviewsAsync = isWorker ? ref.watch(workerReviewsProvider) : ref.watch(userReviewsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
          'My Reviews',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  const Text(
                    'No reviews yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _buildReviewCard(context, review);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, Map<String, dynamic> review) {
    const textPrimary = Color(0xFF1E293B);
    const textSecondary = Color(0xFF94A3B8);
    
    String date = 'Date not set';
    if (review['createdAt'] != null) {
      final timestamp = review['createdAt'] as Timestamp;
      date = DateFormat('MMMM d, yyyy').format(timestamp.toDate());
    }

    final int rating = (review['serviceRating'] ?? review['technicianRating'] ?? 5).toInt();
    final String comment = review['comment'] ?? '';
    final String name = review['serviceName'] ?? review['userName'] ?? 'Service';
    final String reviewId = review['id'];
    final String? profilePic = review['userProfilePic'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 👤 Avatar with Light Blue Background
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: profilePic != null && profilePic.isNotEmpty
                      ? Image.network(profilePic, fit: BoxFit.cover)
                      : const Icon(Icons.person, color: Color(0xFF3B82F6), size: 24),
                ),
              ),
              const SizedBox(width: 14),
              // 👤 Name and Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, 
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // ⭐ Stars on the Right (Blue)
              Row(
                children: List.generate(5, (index) => Icon(
                  Icons.star_rounded,
                  color: index < rating ? Colors.amber : const Color(0xFFE5E7EB),
                  size: 18,
                )),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 18),
            // 💬 Comment Text
            Text(
              comment,
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey.shade500, 
                height: 1.6,
                fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          // 🗑️ Delete Button at Bottom Right
          Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _deleteReview(context, reviewId),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
