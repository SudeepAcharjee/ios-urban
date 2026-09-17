import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/custom_toast.dart';
import '../../home/views/chat_screen.dart';

class ShopBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const ShopBookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<ShopBookingDetailScreen> createState() => _ShopBookingDetailScreenState();
}

class _ShopBookingDetailScreenState extends State<ShopBookingDetailScreen> {
  static const primaryColor = Color(0xFF2029C5);
  bool _isUpdating = false;
  bool _isCleaningExpired = false;

  bool _hasValidBeforeServicePhotos(Map<String, dynamic> data) {
    final rawUrls = data['beforeServiceProofUrls'];
    if (rawUrls is! List || rawUrls.isEmpty) return false;

    final expiry = data['proofExpiresAt'] ?? data['proofExpiryDate'];
    if (expiry is Timestamp) {
      if (DateTime.now().isAfter(expiry.toDate())) {
        _cleanupExpiredPhotos();
        return false;
      }
    }
    return true;
  }

  void _cleanupExpiredPhotos() {
    if (_isCleaningExpired) return;
    _isCleaningExpired = true;
    FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
      'beforeServiceProofUrls': FieldValue.delete(),
      'proofExpiresAt': FieldValue.delete(),
      'proofExpiryDate': FieldValue.delete(),
      'beforeServiceTimestamp': FieldValue.delete(),
    }).catchError((e) => debugPrint('Error cleaning expired proof photos: $e'));
  }

  Future<void> _showStartServicePhotoDialog(Map<String, dynamic> currentData) async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> selectedImages = [];
    bool isUploading = false;
    String uploadStatusText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Service Inspection',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Upload vehicle condition photos to start',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isUploading ? null : () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notice banner about 7-day retention & admin verification
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.shield_outlined, color: Color(0xFF7C3AED), size: 22),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Admin & Dispute Protection',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF5B21B6),
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Photos taken before starting are securely submitted to admin & customer for verification, and will automatically delete after 7 days.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8), height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Image Picker Action Buttons (Camera & Gallery)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () async {
                                          final XFile? photo = await picker.pickImage(
                                            source: ImageSource.camera,
                                            imageQuality: 85,
                                          );
                                          if (photo != null) {
                                            setModalState(() {
                                              selectedImages.add(photo);
                                            });
                                          }
                                        },
                                  icon: const Icon(Icons.photo_camera_rounded, size: 20, color: Color(0xFF7C3AED)),
                                  label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF7C3AED),
                                    side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: const Color(0xFFFAF5FF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () async {
                                          final List<XFile> photos = await picker.pickMultiImage(imageQuality: 85);
                                          if (photos.isNotEmpty) {
                                            setModalState(() {
                                              selectedImages.addAll(photos);
                                            });
                                          }
                                        },
                                  icon: const Icon(Icons.photo_library_rounded, size: 20, color: Color(0xFF2563EB)),
                                  label: const Text('Choose Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFFDBEAFE), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    backgroundColor: const Color(0xFFF0F9FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Photos Preview Grid
                          if (selectedImages.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selected Photos (${selectedImages.length})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                if (!isUploading)
                                  TextButton(
                                    onPressed: () => setModalState(() => selectedImages.clear()),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1,
                              ),
                              itemCount: selectedImages.length,
                              itemBuilder: (ctx, index) {
                                final img = selectedImages[index];
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          File(img.path),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    if (!isUploading)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              selectedImages.removeAt(index);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black87,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, size: 42, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No inspection photos added yet',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Take photo with camera or choose from gallery',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(ctx).padding.bottom),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Column(
                      children: [
                        if (isUploading && uploadStatusText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED))),
                                const SizedBox(width: 8),
                                Text(uploadStatusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (selectedImages.isEmpty || isUploading)
                                ? null
                                : () async {
                                    setModalState(() {
                                      isUploading = true;
                                      uploadStatusText = 'Uploading photos (1/${selectedImages.length})...';
                                    });

                                    try {
                                      final List<String> uploadedUrls = [];
                                      for (int i = 0; i < selectedImages.length; i++) {
                                        setModalState(() {
                                          uploadStatusText = 'Uploading photo (${i + 1}/${selectedImages.length})...';
                                        });
                                        final url = await CloudinaryService.uploadImage(
                                          File(selectedImages[i].path),
                                          folder: 'shop_before_service_proofs',
                                        );
                                        if (url != null && url.isNotEmpty) {
                                          uploadedUrls.add(url);
                                        }
                                      }

                                      if (uploadedUrls.isEmpty) {
                                        throw Exception('Failed to upload inspection photos.');
                                      }

                                      final proofExpiresAt = Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));
                                      final Map<String, dynamic> updates = {
                                        'status': 'In Progress',
                                        'inProgressAt': FieldValue.serverTimestamp(),
                                        'updatedAt': FieldValue.serverTimestamp(),
                                        'statusUpdatedAt': FieldValue.serverTimestamp(),
                                        'beforeServiceProofUrls': uploadedUrls,
                                        'beforeServiceTimestamp': FieldValue.serverTimestamp(),
                                        'proofExpiresAt': proofExpiresAt,
                                        'proofExpiryDate': proofExpiresAt,
                                      };

                                      // Stamp Shop information onto the booking
                                      final currentShopUser = FirebaseAuth.instance.currentUser;
                                      if (currentShopUser != null) {
                                        updates['shopId'] = currentShopUser.uid;
                                        updates['ownerId'] = currentShopUser.uid;
                                        try {
                                          final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(currentShopUser.uid).get();
                                          if (shopDoc.exists && shopDoc.data() != null) {
                                            final sData = shopDoc.data()!;
                                            final sName = sData['shopName'] ?? sData['businessName'] ?? sData['name'];
                                            if (sName != null && sName.toString().trim().isNotEmpty) {
                                              updates['shopName'] = sName.toString().trim();
                                            }
                                            final sImg = sData['shopImage'] ?? sData['bannerImage'] ?? sData['profilePic'] ?? sData['imageUrl'];
                                            if (sImg != null && sImg.toString().trim().isNotEmpty) {
                                              updates['shopImage'] = sImg.toString().trim();
                                            }
                                            final sPhone = sData['phone'] ?? sData['phoneNumber'];
                                            if (sPhone != null && sPhone.toString().trim().isNotEmpty) {
                                              updates['shopPhone'] = sPhone.toString().trim();
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint('Error fetching shop info: $e');
                                        }
                                      }

                                      await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update(updates);

                                      // Notify Customer
                                      final customerId = (currentData['userId'] ?? currentData['customerId'] ?? widget.bookingData['userId'] ?? widget.bookingData['customerId'])?.toString();
                                      final serviceTitle = (currentData['title'] ?? currentData['serviceName'] ?? widget.bookingData['title'] ?? widget.bookingData['serviceName'] ?? 'Service').toString();

                                      if (customerId != null && customerId.isNotEmpty) {
                                        try {
                                          final rtdb = FirebaseDatabase.instanceFor(
                                            app: Firebase.app(),
                                            databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
                                          );
                                          await rtdb.ref('notifications/$customerId').push().set({
                                            'title': 'Service In Progress 🔧',
                                            'message': 'The workshop has started working on "$serviceTitle" with inspection photos attached.',
                                            'type': 'booking_in_progress',
                                            'bookingId': widget.bookingId,
                                            'serviceName': serviceTitle,
                                            'createdAt': ServerValue.timestamp,
                                            'timestamp': ServerValue.timestamp,
                                            'isRead': false,
                                          });
                                        } catch (e) {
                                          debugPrint('Error sending notification: $e');
                                        }
                                      }

                                      if (mounted) {
                                        Navigator.pop(modalCtx);
                                        CustomToast.success(context, 'Service started & inspection photos uploaded successfully!');
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setModalState(() => isUploading = false);
                                        CustomToast.error(context, 'Failed to start service: $e');
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: isUploading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    selectedImages.isEmpty ? 'Take Photos to Start Service' : 'Upload & Start Service (${selectedImages.length})',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
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

  Future<void> _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      CustomToast.error(context, 'Customer phone number is not available.');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        CustomToast.error(context, 'Could not open phone dialer.');
      }
    }
  }

  Future<void> _updateBookingStatus(String newStatus, [Map<String, dynamic>? currentData]) async {
    setState(() => _isUpdating = true);
    try {
      final Map<String, dynamic> updates = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'Confirmed') {
        updates['confirmedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'In Progress') {
        updates['inProgressAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Cancelled') {
        updates['cancelledAt'] = FieldValue.serverTimestamp();
      }

      // Stamp Shop information onto the booking
      final currentShopUser = FirebaseAuth.instance.currentUser;
      if (currentShopUser != null) {
        updates['shopId'] = currentShopUser.uid;
        updates['ownerId'] = currentShopUser.uid;
        try {
          final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(currentShopUser.uid).get();
          if (shopDoc.exists && shopDoc.data() != null) {
            final sData = shopDoc.data()!;
            final sName = sData['shopName'] ?? sData['businessName'] ?? sData['name'];
            if (sName != null && sName.toString().trim().isNotEmpty) {
              updates['shopName'] = sName.toString().trim();
            }
            final sImg = sData['shopImage'] ?? sData['bannerImage'] ?? sData['profilePic'] ?? sData['imageUrl'];
            if (sImg != null && sImg.toString().trim().isNotEmpty) {
              updates['shopImage'] = sImg.toString().trim();
            }
            final sPhone = sData['phone'] ?? sData['phoneNumber'];
            if (sPhone != null && sPhone.toString().trim().isNotEmpty) {
              updates['shopPhone'] = sPhone.toString().trim();
            }
          }
        } catch (e) {
          debugPrint('Error fetching shop info for booking update: $e');
        }
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update(updates);

      // 🔔 Send Realtime Database Notification to Customer
      final customerId = (currentData?['userId'] ?? currentData?['customerId'] ?? widget.bookingData['userId'] ?? widget.bookingData['customerId'])?.toString();
      final serviceTitle = (currentData?['title'] ?? currentData?['serviceName'] ?? widget.bookingData['title'] ?? widget.bookingData['serviceName'] ?? 'Service').toString();

      if (customerId != null && customerId.isNotEmpty) {
        try {
          final rtdb = FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
          );

          String title;
          String message;
          String type;

          if (newStatus == 'Confirmed') {
            title = 'Booking Accepted! 🎉';
            message = 'The workshop has confirmed and accepted your booking for "$serviceTitle".';
            type = 'booking_confirmed';
          } else if (newStatus == 'In Progress') {
            title = 'Service In Progress 🔧';
            message = 'The workshop has started working on your service "$serviceTitle".';
            type = 'booking_in_progress';
          } else if (newStatus == 'Completed') {
            title = 'Service Completed! 🌟';
            message = 'Your service for "$serviceTitle" has been completed successfully.';
            type = 'booking_completed';
          } else if (newStatus == 'Cancelled') {
            title = 'Booking Request Declined ❌';
            message = 'Your booking request for "$serviceTitle" was declined by the workshop.';
            type = 'booking_cancelled';
          } else {
            title = 'Booking Status Updated 📋';
            message = 'Your booking for "$serviceTitle" is now $newStatus.';
            type = 'booking_update';
          }

          await rtdb.ref('notifications/$customerId').push().set({
            'title': title,
            'message': message,
            'type': type,
            'bookingId': widget.bookingId,
            'serviceName': serviceTitle,
            'createdAt': ServerValue.timestamp,
            'timestamp': ServerValue.timestamp,
            'isRead': false,
          });
        } catch (e) {
          debugPrint('Error sending notification to customer: $e');
        }
      }

      if (mounted) {
        CustomToast.success(context, 'Booking updated to $newStatus');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to update booking: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showCancelConfirmationDialog([Map<String, dynamic>? currentData]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Decline Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to decline / cancel this booking request?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _updateBookingStatus('Cancelled', currentData);
            },
            child: const Text('Decline Booking', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      return DateFormat('d MMM yyyy, hh:mm a').format(ts.toDate());
    }
    if (ts is String && ts.isNotEmpty) {
      return ts;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data?.data() != null
            ? {
                ...widget.bookingData,
                ...snapshot.data!.data()!,
                'id': widget.bookingId,
              }
            : widget.bookingData;

        final title = (data['title'] ?? data['serviceName'] ?? 'Service').toString();
        final customerName = (data['userName'] ?? data['customerName'] ?? 'Customer').toString();
        final customerPhone = (data['userPhone'] ?? data['phone'] ?? '').toString();
        final customerId = (data['userId'] ?? data['customerId'] ?? '').toString();
        final price = (data['totalPrice'] ?? data['price'] ?? 0).toString();
        final status = (data['status'] ?? 'Pending').toString();
        final rawDate = data['date'] ?? data['bookingDate'];
        final timeSlot = (data['time'] ?? data['timeSlot'] ?? '').toString();
        final vehicleModel = (data['carModel'] ?? data['vehicleName'] ?? data['vehicle'] ?? '').toString();
        final vehicleNumber = (data['vehicleNumber'] ?? data['carNumber'] ?? '').toString();
        final serviceImage = (data['imagePath'] ?? data['serviceImage'] ?? data['imageUrl'] ?? '').toString();
        
        final rawAddress = data['address'];
        String address = '';
        if (rawAddress is Map) {
          address = (rawAddress['address'] ?? rawAddress['doorstepAddress'] ?? '').toString();
        } else if (rawAddress is String) {
          address = rawAddress;
        }

        String dateStr = '';
        if (rawDate != null) {
          if (rawDate is Timestamp) {
            dateStr = DateFormat('d MMM, yyyy').format(rawDate.toDate());
          } else {
            dateStr = rawDate.toString();
          }
        }

        final stLower = status.toLowerCase();
        final isCancelled = stLower == 'cancelled';
        final isCompleted = stLower == 'completed' || stLower == 'job completed';
        final isInProgress = stLower == 'in progress' || stLower == 'in-progress';
        final isConfirmed = stLower == 'confirmed' || stLower == 'assigned';
        final isPending = stLower == 'pending';

        Color statusColor;
        Color statusBg;
        if (isPending) {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFEF3C7);
        } else if (isConfirmed) {
          statusColor = const Color(0xFF2563EB);
          statusBg = const Color(0xFFDBEAFE);
        } else if (isInProgress) {
          statusColor = const Color(0xFF7C3AED);
          statusBg = const Color(0xFFEDE9FE);
        } else if (isCompleted) {
          statusColor = const Color(0xFF059669);
          statusBg = const Color(0xFFD1FAE5);
        } else {
          statusColor = Colors.red.shade700;
          statusBg = Colors.red.shade50;
        }

        // Timestamps for tracking progress
        final placedTime = _formatTimestamp(data['createdAt']);
        final confirmedTime = _formatTimestamp(data['confirmedAt'] ?? (isConfirmed || isInProgress || isCompleted ? data['statusUpdatedAt'] : null));
        final inProgressTime = _formatTimestamp(data['inProgressAt'] ?? (isInProgress || isCompleted ? data['statusUpdatedAt'] : null));
        final completedTime = _formatTimestamp(data['completedAt'] ?? (isCompleted ? data['statusUpdatedAt'] : null));
        final cancelledTime = _formatTimestamp(data['cancelledAt'] ?? (isCancelled ? data['statusUpdatedAt'] : null));

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'ID: #${widget.bookingId.length > 8 ? widget.bookingId.substring(widget.bookingId.length - 8) : widget.bookingId}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 36.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CUSTOMER & CONTACT DETAILS CARD (Person Name, Calling Option, Chat Option)
                  _buildCustomerCard(
                    context: context,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerId: customerId,
                    address: address,
                    serviceName: title,
                  ),
                  const SizedBox(height: 16),

                  // 2. FLIPKART / AMAZON STYLE TRACK RECORD PROGRESS BAR / STEPPER
                  _buildOrderTrackerCard(
                    status: status,
                    isPending: isPending,
                    isConfirmed: isConfirmed,
                    isInProgress: isInProgress,
                    isCompleted: isCompleted,
                    isCancelled: isCancelled,
                    placedTime: placedTime,
                    confirmedTime: confirmedTime,
                    inProgressTime: inProgressTime,
                    completedTime: completedTime,
                    cancelledTime: cancelledTime,
                  ),
                  const SizedBox(height: 16),

                  // 3. BEFORE SERVICE VEHICLE INSPECTION PHOTOS (7-Day Retention / Auto Deletion)
                  if (_hasValidBeforeServicePhotos(data)) ...[
                    _buildBeforeServicePhotosCard(data),
                    const SizedBox(height: 16),
                  ],

                  // 4. SERVICE & VEHICLE SUMMARY CARD
                  _buildServiceInfoCard(
                    title: title,
                    vehicleModel: vehicleModel,
                    vehicleNumber: vehicleNumber,
                    dateStr: dateStr,
                    timeSlot: timeSlot,
                    price: price,
                    serviceImage: serviceImage,
                    category: data['category']?.toString() ?? '',
                  ),
                  const SizedBox(height: 16),

                  // 4. PAYMENT & BILLING SUMMARY CARD
                  _buildPaymentSummaryCard(
                    price: price,
                    paymentMethod: data['paymentMethod']?.toString() ?? 'Cash',
                    paymentStatus: data['paymentStatus']?.toString() ?? (isCompleted ? 'Paid' : 'Pending'),
                    razorpayPaymentId: data['razorpayPaymentId']?.toString(),
                  ),
                  const SizedBox(height: 24),

                  // 5. WORKSHOP STATUS ACTION BUTTONS
                  if (!isCompleted && !isCancelled) ...[
                    _buildActionControls(
                      context: context,
                      isPending: isPending,
                      isConfirmed: isConfirmed,
                      isInProgress: isInProgress,
                      data: data,
                    ),
                    const SizedBox(height: 36),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // CUSTOMER DETAILS CARD WITH PERSON NAME, CALLING AND CHAT BUTTONS
  Widget _buildCustomerCard({
    required BuildContext context,
    required String customerName,
    required String customerPhone,
    required String customerId,
    required String address,
    required String serviceName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_pin_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Customer Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // User Info Stream or Fallback
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: customerId.isNotEmpty
                ? FirebaseFirestore.instance.collection('users').doc(customerId).snapshots()
                : null,
            builder: (context, userSnap) {
              String displayName = customerName;
              String displayPhone = customerPhone;
              String? userImage;

              if (userSnap.hasData && userSnap.data?.data() != null) {
                final uData = userSnap.data!.data()!;
                if (uData['name'] != null && uData['name'].toString().isNotEmpty) {
                  displayName = uData['name'].toString();
                } else if (uData['fullName'] != null && uData['fullName'].toString().isNotEmpty) {
                  displayName = uData['fullName'].toString();
                }
                if (uData['phone'] != null && uData['phone'].toString().isNotEmpty) {
                  displayPhone = uData['phone'].toString();
                } else if (uData['phoneNumber'] != null && uData['phoneNumber'].toString().isNotEmpty) {
                  displayPhone = uData['phoneNumber'].toString();
                }
                userImage = uData['profilePic'] ?? uData['photoUrl'] ?? uData['imageUrl'];
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: primaryColor.withOpacity(0.1),
                        backgroundImage: (userImage != null && userImage.isNotEmpty)
                            ? NetworkImage(userImage)
                            : null,
                        child: (userImage == null || userImage.isEmpty)
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayPhone.isNotEmpty ? displayPhone : 'Phone not provided',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: primaryColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // CALL & CHAT ACTION BUTTONS
                  Row(
                    children: [
                      // CALL BUTTON
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: displayPhone.isNotEmpty ? () => _callCustomer(displayPhone) : null,
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text(
                            'Call Customer',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // CHAT BUTTON
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  providerName: displayName,
                                  providerRole: 'Customer',
                                  bookingId: 'bookings/${widget.bookingId}',
                                  imageUrl: userImage,
                                  recipientId: customerId.isNotEmpty ? customerId : null,
                                  recipientRole: 'user',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text(
                            'Chat',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // FLIPKART / AMAZON STYLE STEP PROGRESS TRACKER
  Widget _buildOrderTrackerCard({
    required String status,
    required bool isPending,
    required bool isConfirmed,
    required bool isInProgress,
    required bool isCompleted,
    required bool isCancelled,
    required String placedTime,
    required String confirmedTime,
    required String inProgressTime,
    required String completedTime,
    required String cancelledTime,
  }) {
    // Step activation flags
    // Step 1: Placed (Always true unless empty)
    final bool step1Active = true;
    final bool step1Done = isConfirmed || isInProgress || isCompleted;

    // Step 2: Confirmed
    final bool step2Active = isConfirmed || isInProgress || isCompleted;
    final bool step2Done = isInProgress || isCompleted;

    // Step 3: In Progress
    final bool step3Active = isInProgress || isCompleted;
    final bool step3Done = isCompleted;

    // Step 4: Completed
    final bool step4Active = isCompleted;
    final bool step4Done = isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Track Booking Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 18),

          if (isCancelled) ...[
            _buildTrackerStep(
              title: 'Booking Placed',
              description: 'Customer created the service request',
              time: placedTime,
              isDone: true,
              isActive: true,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),
            _buildTrackerStep(
              title: 'Booking Cancelled',
              description: 'This booking request was cancelled',
              time: cancelledTime.isNotEmpty ? cancelledTime : 'Cancelled',
              isDone: true,
              isActive: true,
              isLast: true,
              activeColor: Colors.red,
              nodeIcon: Icons.close_rounded,
            ),
          ] else ...[
            // STEP 1: BOOKING PLACED
            _buildTrackerStep(
              title: 'Booking Placed',
              description: 'Customer placed the service request',
              time: placedTime,
              isDone: step1Done,
              isActive: step1Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 2: BOOKING CONFIRMED / ACCEPTED
            _buildTrackerStep(
              title: 'Booking Confirmed',
              description: step2Active
                  ? 'Workshop accepted this booking'
                  : 'Awaiting acceptance from workshop',
              time: confirmedTime,
              isDone: step2Done,
              isActive: step2Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 3: SERVICE IN PROGRESS
            _buildTrackerStep(
              title: 'Service In Progress',
              description: step3Active
                  ? 'Vehicle is actively being serviced'
                  : 'Waiting for vehicle arrival / service start',
              time: inProgressTime,
              isDone: step3Done,
              isActive: step3Active,
              isLast: false,
              activeColor: const Color(0xFF059669),
            ),

            // STEP 4: SERVICE COMPLETED
            _buildTrackerStep(
              title: 'Service Completed',
              description: step4Active
                  ? 'Service completed successfully & ready'
                  : 'Service will be marked done upon completion',
              time: completedTime,
              isDone: step4Done,
              isActive: step4Active,
              isLast: true,
              activeColor: const Color(0xFF059669),
            ),
          ],
        ],
      ),
    );
  }

  // FLIPKART/AMAZON STEP TRACKER ITEM
  Widget _buildTrackerStep({
    required String title,
    required String description,
    required String time,
    required bool isDone,
    required bool isActive,
    required bool isLast,
    required Color activeColor,
    IconData? nodeIcon,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left tracker node + vertical connecting line
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? activeColor
                      : (isActive ? activeColor.withOpacity(0.15) : const Color(0xFFF1F5F9)),
                  border: Border.all(
                    color: isActive ? activeColor : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(
                          nodeIcon ?? Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : (isActive
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                            )
                          : Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            )),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isDone ? activeColor : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Right step details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SERVICE & VEHICLE SUMMARY CARD
  Widget _buildServiceInfoCard({
    required String title,
    required String vehicleModel,
    required String vehicleNumber,
    required String dateStr,
    required String timeSlot,
    required String price,
    required String serviceImage,
    required String category,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Service Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 65,
                  height: 65,
                  color: const Color(0xFFF1F5F9),
                  child: serviceImage.isNotEmpty
                      ? Image.network(
                          serviceImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.directions_car_rounded,
                            color: primaryColor,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.directions_car_rounded,
                          color: primaryColor,
                          size: 32,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '₹$price',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Vehicle & Schedule Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (vehicleModel.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Vehicle: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      Text(
                        vehicleModel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      if (vehicleNumber.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('($vehicleNumber)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (dateStr.isNotEmpty || timeSlot.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Scheduled: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                      Text(
                        [if (dateStr.isNotEmpty) dateStr, if (timeSlot.isNotEmpty) timeSlot].join(' • '),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdatePaymentDialog({
    required String currentPaymentStatus,
    required String currentPaymentMethod,
    String? currentTxId,
  }) {
    String selectedStatus = (currentPaymentStatus.toLowerCase() == 'paid') ? 'Paid' : 'Pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isModalPaid = selectedStatus.toLowerCase() == 'paid';
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.payment_rounded, color: primaryColor, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Update Cash Payment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Status Selector
                  const Text(
                    'Payment Status',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedStatus = 'Paid'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isModalPaid ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isModalPaid ? const Color(0xFF059669) : Colors.grey.shade300,
                                width: isModalPaid ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: isModalPaid ? const Color(0xFF059669) : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cash Paid',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isModalPaid ? const Color(0xFF059669) : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedStatus = 'Pending'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: !isModalPaid ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: !isModalPaid ? const Color(0xFFD97706) : Colors.grey.shade300,
                                width: !isModalPaid ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 20,
                                  color: !isModalPaid ? const Color(0xFFD97706) : Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pending',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: !isModalPaid ? const Color(0xFFD97706) : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isUpdating = true);
                        try {
                          final updates = {
                            'paymentStatus': selectedStatus,
                            'paymentMethod': 'Cash',
                            'paymentUpdatedAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          await FirebaseFirestore.instance
                              .collection('bookings')
                              .doc(widget.bookingId)
                              .update(updates);

                          if (mounted) {
                            CustomToast.success(this.context, 'Payment updated to $selectedStatus (Cash)');
                          }
                        } catch (e) {
                          if (mounted) {
                            CustomToast.error(this.context, 'Failed to update payment: $e');
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isUpdating = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save Payment Details',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  // PAYMENT & BILLING SUMMARY CARD
  Widget _buildPaymentSummaryCard({
    required String price,
    required String paymentMethod,
    required String paymentStatus,
    String? razorpayPaymentId,
  }) {
    final isPaid = paymentStatus.toLowerCase() == 'paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Payment Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaid ? 'PAID' : 'PAYMENT PENDING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          _buildSummaryRow('Payment Mode', paymentMethod),
          if (razorpayPaymentId != null && razorpayPaymentId.isNotEmpty)
            _buildSummaryRow('Transaction ID', razorpayPaymentId),
          _buildSummaryRow('Service Price', '₹$price'),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '₹$price',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // UPDATE PAYMENT BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showUpdatePaymentDialog(
                currentPaymentStatus: paymentStatus,
                currentPaymentMethod: paymentMethod,
                currentTxId: razorpayPaymentId,
              ),
              icon: Icon(
                isPaid ? Icons.edit_outlined : Icons.payment_rounded,
                size: 18,
              ),
              label: Text(
                isPaid ? 'Update Payment Details' : 'Update Payment Status',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPaid ? primaryColor.withOpacity(0.08) : const Color(0xFF059669),
                foregroundColor: isPaid ? primaryColor : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isPaid ? BorderSide(color: primaryColor.withOpacity(0.3)) : BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // WORKSHOP STATUS ACTION BUTTONS
  Widget _buildActionControls({
    required BuildContext context,
    required bool isPending,
    required bool isConfirmed,
    required bool isInProgress,
    required Map<String, dynamic> data,
  }) {
    if (_isUpdating) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCancelConfirmationDialog(data),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Decline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _updateBookingStatus('Confirmed', data),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Accept Booking', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (isConfirmed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showStartServicePhotoDialog(data),
          icon: const Icon(Icons.photo_camera_rounded, size: 22),
          label: const Text('Start Service & Upload Photos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    if (isInProgress) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _updateBookingStatus('Completed', data),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
          label: const Text('Mark Service as Completed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // BEFORE-SERVICE VEHICLE INSPECTION PHOTOS CARD WITH 7-DAY RETENTION
  Widget _buildBeforeServicePhotosCard(Map<String, dynamic> data) {
    final List<dynamic> rawUrls = data['beforeServiceProofUrls'] ?? [];
    final List<String> urls = rawUrls.map((e) => e.toString()).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final expiry = data['proofExpiresAt'] ?? data['proofExpiryDate'];
    int daysLeft = 7;
    String expiryFormatted = '';
    if (expiry is Timestamp) {
      final expDate = expiry.toDate();
      daysLeft = expDate.difference(DateTime.now()).inDays + 1;
      if (daysLeft < 0) daysLeft = 0;
      expiryFormatted = DateFormat('d MMM, hh:mm a').format(expDate);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Before-Service Photos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Initial inspection proof',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              // Auto-delete badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFEA580C)),
                    const SizedBox(width: 4),
                    Text(
                      daysLeft <= 0 ? 'Deleting soon' : 'Auto-deletes in $daysLeft d',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Thumbnails row
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, index) {
                final imgUrl = urls[index];
                return GestureDetector(
                  onTap: () => _showImagePreviewDialog(context, imgUrl, index, urls),
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          image: DecorationImage(
                            image: NetworkImage(imgUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  expiryFormatted.isNotEmpty
                      ? 'Retained until $expiryFormatted for admin verification before auto-deletion.'
                      : 'Auto-deletes after 7 days for admin & customer security.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FULLSCREEN IMAGE VIEWER WITH PINCH ZOOM
  void _showImagePreviewDialog(BuildContext context, String currentUrl, int initialIndex, List<String> allUrls) {
    showDialog(
      context: context,
      builder: (ctx) {
        int activeIndex = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.black.withOpacity(0.92),
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: allUrls.length,
                    onPageChanged: (i) => setDialogState(() => activeIndex = i),
                    itemBuilder: (pageCtx, idx) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            allUrls[idx],
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: MediaQuery.of(ctx).padding.top + 10,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${activeIndex + 1} / ${allUrls.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
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
}
