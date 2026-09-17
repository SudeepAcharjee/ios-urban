import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;
  const WriteReviewScreen({super.key, required this.bookingData});

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  bool _isRecommended = true;
  String _selectedImpression = 'Service Quality';
  int _serviceRating = 5;
  int _technicianRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Authentication Error'),
          description: const Text('Please login to submit a review.'),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userData = ref.read(userDataProvider).value;
      final String userId = currentUser.uid;
      final String userName = (userData?['name'] != null && userData!['name'].toString().trim().isNotEmpty)
          ? userData['name']
          : (currentUser.displayName?.trim().isNotEmpty == true ? currentUser.displayName! : 'Customer');
      final String userProfilePic = userData?['profilePic'] ?? currentUser.photoURL ?? '';

      final String serviceId = (widget.bookingData['serviceId'] ?? '').toString();
      final String serviceName = (widget.bookingData['serviceName'] ?? widget.bookingData['title'] ?? widget.bookingData['serviceTitle'] ?? 'Service').toString();
      final String bookingId = (widget.bookingData['bookingId'] ?? widget.bookingData['id'] ?? '').toString();

      final String? rawShopId = widget.bookingData['shopId'] ?? widget.bookingData['ownerId'];
      final String? shopId = (rawShopId != null && rawShopId.toString().trim().isNotEmpty) ? rawShopId.toString().trim() : null;
      final String? shopName = widget.bookingData['shopName']?.toString().trim();

      final String? rawWorkerId = widget.bookingData['workerId'];
      final String? workerId = (rawWorkerId != null && rawWorkerId.toString().trim().isNotEmpty) ? rawWorkerId.toString().trim() : null;
      final String? workerName = widget.bookingData['workerName']?.toString().trim();

      final reviewData = <String, dynamic>{
        'userId': userId,
        'userName': userName,
        'userProfilePic': userProfilePic,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'title': serviceName,
        'bookingId': bookingId,
        'serviceRating': _serviceRating,
        'technicianRating': _technicianRating,
        'rating': _serviceRating.toDouble(),
        'comment': _commentController.text.trim(),
        'isRecommended': _isRecommended,
        'impression': _selectedImpression,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'isDisabled': false,
        'technicianName': workerName ?? shopName ?? 'Service Provider',
      };

      if (shopId != null) {
        reviewData['shopId'] = shopId;
        reviewData['ownerId'] = shopId;
      }
      if (shopName != null && shopName.isNotEmpty) {
        reviewData['shopName'] = shopName;
      }
      if (workerId != null) {
        reviewData['workerId'] = workerId;
      }
      if (workerName != null && workerName.isNotEmpty) {
        reviewData['workerName'] = workerName;
      }

      // 1. Add review to Firestore
      await FirebaseFirestore.instance.collection('reviews').add(reviewData);

      // 2. Mark booking as reviewed
      if (bookingId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
            'isReviewed': true,
            'reviewSubmitted': true,
            'serviceRating': _serviceRating,
            'technicianRating': _technicianRating,
            'comment': _commentController.text.trim(),
          });
        } catch (e) {
          debugPrint('Error updating booking review status: $e');
        }
      }

      // 3. Update Shop Rating & send notification if this is a shop service
      if (shopId != null) {
        try {
          final shopReviewsSnap = await FirebaseFirestore.instance
              .collection('reviews')
              .where('shopId', isEqualTo: shopId)
              .get();
          
          if (shopReviewsSnap.docs.isNotEmpty) {
            double totalRating = 0.0;
            for (final doc in shopReviewsSnap.docs) {
              final rData = doc.data();
              final r = (rData['serviceRating'] ?? rData['rating'] ?? 5.0) as num;
              totalRating += r.toDouble();
            }
            final avgRating = double.parse((totalRating / shopReviewsSnap.docs.length).toStringAsFixed(1));
            await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
              'rating': avgRating,
              'totalReviews': shopReviewsSnap.docs.length,
            });
          }
        } catch (e) {
          debugPrint('Error updating shop rating: $e');
        }

        try {
          final rtdb = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
          );
          await rtdb.ref('notifications/$shopId').push().set({
            'title': 'New Review Received! ⭐',
            'message': '$userName gave a $_serviceRating-star review for "$serviceName".',
            'type': 'review',
            'bookingId': bookingId,
            'rating': _serviceRating,
            'comment': _commentController.text.trim(),
            'createdAt': ServerValue.timestamp,
            'timestamp': ServerValue.timestamp,
            'isRead': false,
          });
        } catch (e) {
          debugPrint('Error sending review notification to shop: $e');
        }
      }

      // 4. Update Worker Rating & send notification if worker was assigned
      if (workerId != null) {
        try {
          final workerReviewsSnap = await FirebaseFirestore.instance
              .collection('reviews')
              .where('workerId', isEqualTo: workerId)
              .get();
          
          if (workerReviewsSnap.docs.isNotEmpty) {
            double totalRating = 0.0;
            for (final doc in workerReviewsSnap.docs) {
              final rData = doc.data();
              final r = (rData['technicianRating'] ?? rData['rating'] ?? 5.0) as num;
              totalRating += r.toDouble();
            }
            final avgRating = double.parse((totalRating / workerReviewsSnap.docs.length).toStringAsFixed(1));
            await FirebaseFirestore.instance.collection('workers').doc(workerId).update({
              'rating': avgRating,
              'totalReviews': workerReviewsSnap.docs.length,
            });
          }
        } catch (e) {
          debugPrint('Error updating worker rating: $e');
        }

        try {
          final rtdb = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
          );
          await rtdb.ref('notifications/$workerId').push().set({
            'title': 'New Feedback Received! ⭐',
            'message': '$userName rated your service $_technicianRating stars.',
            'type': 'review',
            'bookingId': bookingId,
            'rating': _technicianRating,
            'comment': _commentController.text.trim(),
            'createdAt': ServerValue.timestamp,
            'timestamp': ServerValue.timestamp,
            'isRead': false,
          });
        } catch (e) {
          debugPrint('Error sending review notification to worker: $e');
        }
      }

      if (mounted) {
        _showSuccessBottomSheet(context, const Color(0xFF2029C5));
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error Submitting Review'),
          description: Text(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2029C5);
    final bool isShopBooking = (widget.bookingData['shopId'] != null && widget.bookingData['shopId'].toString().isNotEmpty) ||
        (widget.bookingData['ownerId'] != null && widget.bookingData['ownerId'].toString().isNotEmpty);
    final String? shopName = widget.bookingData['shopName']?.toString();
    final String? workerName = widget.bookingData['workerName']?.toString();
    final String providerDisplayName = isShopBooking 
        ? (shopName ?? 'Workshop Service')
        : (workerName ?? 'Technician');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text(
          'Write a Review',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Service Rating Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Service was Excellent',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildStarRating(_serviceRating, (val) => setState(() => _serviceRating = val)),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRecommended,
                        onChanged: (val) => setState(() => _isRecommended = val!),
                        activeColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      const Expanded(
                        child: Text(
                          'I recommend this service provider to my friends',
                          style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Impressions Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What impressed you?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildImpressionChip('Service Quality', primaryGreen),
                        const SizedBox(width: 10),
                        _buildImpressionChip(isShopBooking ? 'Workshop Service' : 'Technician Behaviour', primaryGreen),
                        const SizedBox(width: 10),
                        _buildImpressionChip('On Time Service', primaryGreen),
                        const SizedBox(width: 10),
                        _buildImpressionChip('Customer Support', primaryGreen),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Provider / Technician Rating Card
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isShopBooking ? 'Rate Workshop Experience' : 'Rate Technician',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (providerDisplayName.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          isShopBooking ? Icons.storefront_rounded : Icons.person_rounded, 
                          size: 18, 
                          color: primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            providerDisplayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildStarRating(_technicianRating, (val) => setState(() => _technicianRating = val)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Add a Comment...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isSubmitting 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showSuccessBottomSheet(BuildContext context, Color themeColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SuccessDialogContent(themeColor: themeColor),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStarRating(int rating, Function(int) onRatingChanged, {double size = 45}) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          return GestureDetector(
            onTap: () => onRatingChanged(index + 1),
            child: Icon(
              Icons.star,
              color: index < rating ? Colors.amber : Colors.grey.shade300,
              size: size,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildImpressionChip(String title, Color themeColor) {
    bool isSelected = _selectedImpression == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedImpression = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class SuccessDialogContent extends StatefulWidget {
  final Color themeColor;
  const SuccessDialogContent({super.key, required this.themeColor});

  @override
  State<SuccessDialogContent> createState() => _SuccessDialogContentState();
}

class _SuccessDialogContentState extends State<SuccessDialogContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeTitle;
  late Animation<Offset> _slideTitle;
  late Animation<double> _fadeDesc;
  late Animation<Offset> _slideDesc;
  late Animation<double> _fadeButton;
  late Animation<Offset> _slideButton;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut))
    );
    
    _fadeTitle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.6, curve: Curves.easeIn))
    );
    _slideTitle = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.6, curve: Curves.easeOutCubic))
    );
    
    _fadeDesc = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.8, curve: Curves.easeIn))
    );
    _slideDesc = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 0.8, curve: Curves.easeOutCubic))
    );
    
    _fadeButton = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0, curve: Curves.easeIn))
    );
    _slideButton = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.8, 1.0, curve: Curves.easeOutCubic))
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(30, 30, 30, 30 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.themeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: widget.themeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          FadeTransition(
            opacity: _fadeTitle,
            child: SlideTransition(
              position: _slideTitle,
              child: const Text(
                'Thanks for giving\nyour feedback',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          FadeTransition(
            opacity: _fadeDesc,
            child: SlideTransition(
              position: _slideDesc,
              child: Text(
                'Your feedback means a lot for the rating and improvement for our services.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _fadeButton,
            child: SlideTransition(
              position: _slideButton,
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.pop(context); // Go back to booking details
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
