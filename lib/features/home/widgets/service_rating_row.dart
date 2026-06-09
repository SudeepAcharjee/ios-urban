import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_washing_service_app/features/home/providers/review_provider.dart';

class ServiceRatingRow extends ConsumerWidget {
  final String serviceName;
  final double fontSize;
  final double starSize;
  
  final bool showReviewText;
  
  const ServiceRatingRow({
    super.key, 
    required this.serviceName,
    this.fontSize = 12,
    this.starSize = 14,
    this.showReviewText = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsProvider(serviceName));
    
    return reviewsAsync.when(
      data: (reviews) {
        final double avgRating = reviews.isEmpty ? 0.0 : (reviews.fold(0.0, (acc, r) => acc + r.rating) / reviews.length);
        final int count = reviews.length;
        
        return Row(
          children: [
            Row(
              children: List.generate(5, (index) => Icon(
                Icons.star_rounded,
                color: index < avgRating.round() ? const Color(0xFFFFB800) : Colors.grey.shade300, 
                size: starSize,
              )),
            ),
            const SizedBox(width: 4),
            Text(
              showReviewText ? '($count Reviews)' : '($count)',
              style: TextStyle(color: const Color(0xFF6B7280), fontSize: fontSize),
            ),
          ],
        );
      },
      loading: () => Row(
        children: [
          Row(
            children: List.generate(5, (index) => Icon(
              Icons.star,
              color: Colors.grey.shade200, 
              size: starSize,
            )),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 40, height: 10, child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade300))),
        ],
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}
