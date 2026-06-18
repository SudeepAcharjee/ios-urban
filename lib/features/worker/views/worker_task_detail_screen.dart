import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/views/chat_screen.dart';
import 'worker_payment.dart';
import '../../../core/services/notification_service.dart';

class WorkerTaskDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> taskData;

  const WorkerTaskDetailScreen({
    super.key,
    required this.taskData,
  });

  @override
  ConsumerState<WorkerTaskDetailScreen> createState() => _WorkerTaskDetailScreenState();
}

class _WorkerTaskDetailScreenState extends ConsumerState<WorkerTaskDetailScreen> {
  static const primaryColor = Color(0xFF2029C5);
  late String _status;
  bool _isUpdating = false;
  bool _hasUploadedProof = false;
  bool _isPaid = false;

  bool get _shouldHideCustomerAndLocation => _status == 'Completed' || (_status == 'Pending Verification' && _isPaid);

  @override
  void initState() {
    super.initState();
    _status = widget.taskData['status'] ?? 'Assigned';
    _hasUploadedProof = widget.taskData['proofUrls'] != null && 
        (widget.taskData['proofUrls'] as List).isNotEmpty;
    _isPaid = widget.taskData['paymentStatus'] == 'Paid';
    _getCoordinatesFromAddress();
  }

  Future<void> _getCoordinatesFromAddress() async {
    final String? address = widget.taskData['address'];
    if (address == null || address.isEmpty) return;

    try {
      List<geo.Location> locations = await geo.locationFromAddress(address);
      if (locations.isNotEmpty) {
        if (mounted) {
          setState(() {
          });
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final bookingId = widget.taskData['id'];
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'In Progress') {
        updateData['inProgressAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Pending Verification') {
        updateData['submittedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Cancelled') {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);

      setState(() => _status = newStatus);

      if (newStatus == 'Pending Verification') {
        try {
          final workerInfo = ref.read(userDataProvider).value;
          final String workerId = workerInfo?['uid'] ?? workerInfo?['id'] ?? 'unknown';
          final String workerName = workerInfo?['name'] ?? 'Worker';
          final String bookingTitle = widget.taskData['title'] ?? 'Service';

          await NotificationService.notifyAdminsAboutPendingVerification(
            bookingId: bookingId,
            bookingTitle: bookingTitle,
            workerId: workerId,
            workerName: workerName,
          );
        } catch (notifyErr) {
          debugPrint('Failed to send admin notification: $notifyErr');
        }
      }

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text('Status Updated to $newStatus'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error Updating Status'),
          description: Text(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _showBeforeServiceDialog() async {
    final ImagePicker picker = ImagePicker();
    List<XFile> pickedImages = [];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 35),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Before Service', 
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Capture photos of the vehicle before starting', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.normal),
                    ),
                    const SizedBox(height: 20),
                    if (pickedImages.isNotEmpty)
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pickedImages.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Image.file(
                                      File(pickedImages[index].path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() => pickedImages.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      CustomPaint(
                        painter: DashedBorderPainter(
                          color: const Color(0xFFC7D2FE),
                          borderRadius: 20,
                        ),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.image_rounded, size: 28, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No photos selected', 
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add photos to continue', 
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final XFile? image = await picker.pickImage(source: ImageSource.camera);
                              if (image != null) setDialogState(() => pickedImages.add(image));
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 20, color: Color(0xFF2563EB)),
                            label: const Text(
                              'Camera', 
                              style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final List<XFile> images = await picker.pickMultiImage();
                              if (images.isNotEmpty) setDialogState(() => pickedImages.addAll(images));
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 20, color: Color(0xFF2563EB)),
                            label: const Text(
                              'Gallery', 
                              style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: (pickedImages.isEmpty || _isUpdating) ? null : () async {
                            setDialogState(() => _isUpdating = true);
                            try {
                              await _uploadBeforeServiceImages(pickedImages);
                              if (mounted) {
                                Navigator.pop(context);
                                _showOTPDialog();
                              }
                            } finally {
                              if (mounted) setDialogState(() => _isUpdating = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF2563EB).withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isUpdating 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Upload & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                              if (!_isUpdating) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 42,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 32,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadBeforeServiceImages(List<XFile> pickedImages) async {
    List<String> urls = [];
    for (var image in pickedImages) {
      final url = await CloudinaryService.uploadImage(File(image.path), folder: 'before_service_proofs');
      if (url != null) urls.add(url);
    }
    if (urls.isNotEmpty) {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.taskData['id']).update({
        'beforeServiceProofUrls': urls,
      });
    } else {
      throw 'Failed to upload before-service images.';
    }
  }

  Future<void> _showCompleteServiceDialog() async {
    final ImagePicker picker = ImagePicker();
    List<XFile> pickedImages = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 35),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'After Service', 
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Capture photos of the vehicle after finishing', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.normal),
                    ),
                    const SizedBox(height: 20),
                    if (pickedImages.isNotEmpty)
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pickedImages.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Image.file(
                                      File(pickedImages[index].path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => setDialogState(() => pickedImages.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      CustomPaint(
                        painter: DashedBorderPainter(
                          color: const Color(0xFFA7F3D0),
                          borderRadius: 20,
                        ),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.image_rounded, size: 28, color: Color(0xFF059669)),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No photos selected', 
                                style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add photos to continue', 
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final XFile? image = await picker.pickImage(source: ImageSource.camera);
                              if (image != null) setDialogState(() => pickedImages.add(image));
                            },
                            icon: const Icon(Icons.camera_alt_rounded, size: 20, color: Color(0xFF059669)),
                            label: const Text(
                              'Camera', 
                              style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF059669),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final List<XFile> images = await picker.pickMultiImage();
                              if (images.isNotEmpty) setDialogState(() => pickedImages.addAll(images));
                            },
                            icon: const Icon(Icons.photo_library_rounded, size: 20, color: Color(0xFF059669)),
                            label: const Text(
                              'Gallery', 
                              style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF059669),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: const Text(
                            'Cancel', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: (pickedImages.isEmpty || _isUpdating) ? null : () async {
                            setDialogState(() => _isUpdating = true); 
                            try {
                              await _processCompletion(pickedImages);
                              if (mounted) {
                                Navigator.pop(context); // Close the dialog
                                
                                // Navigate to the payment screen
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkerPaymentScreen(taskData: widget.taskData),
                                  ),
                                );
                                if (result == true && mounted) {
                                  setState(() {
                                    _status = 'Pending Verification';
                                    _isPaid = true;
                                  });
                                }
                              }
                            } finally {
                              if (mounted) setDialogState(() => _isUpdating = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF059669).withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _isUpdating 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Continue to Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                              if (!_isUpdating) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 42,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 32,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCompletion(List<XFile> imageFiles) async {
    setState(() => _isUpdating = true);
    try {
      final workerInfo = ref.read(userDataProvider).value;
      if (workerInfo == null) throw 'Worker information not found. Please log in again.';

      final String bookingId = widget.taskData['id'];
      final String workerId = workerInfo['uid'] ?? workerInfo['id'] ?? 'unknown';
      final String workerName = workerInfo['name'] ?? 'Worker';
      final String workerEmail = workerInfo['email'] ?? '';
      
      // 1. Upload all images to Cloudinary
      List<String> proofUrls = [];
      for (var file in imageFiles) {
        final String? url = await CloudinaryService.uploadImage(File(file.path), folder: 'service_proofs');
        if (url != null) proofUrls.add(url);
      }
      
      if (proofUrls.isEmpty) throw 'Failed to upload proof images.';

      // Fetch Before Service images to include in the final proof record
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
      final List<String> beforeServiceUrls = List<String>.from(bookingDoc.data()?['beforeServiceProofUrls'] ?? []);

      // 2. Update Booking with proof
      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'proofUrls': proofUrls, 
      });

      // 3. Add to service_proof collection
      await FirebaseFirestore.instance.collection('service_proof').add({
        'bookingId': bookingId,
        'workerId': workerId,
        'workerName': workerName,
        'workerEmail': workerEmail,
        'proofUrls': proofUrls,
        'beforeServiceProofUrls': beforeServiceUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'title': widget.taskData['title'] ?? 'Service',
      });

      setState(() {
        _hasUploadedProof = true;
      });

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Proof Uploaded!'),
          description: const Text('Proof has been uploaded. Proceeding to payment.'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error Completing Service'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }


  Future<void> _openMap(String address) async {
    final String encodedAddress = Uri.encodeComponent(address);
    final Uri googleMapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedAddress");
    
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Could not open map'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.taskData['title'] ?? 'Service';
    final String bookingId = widget.taskData['id'] ?? 'ID Not Available';
    final String address = widget.taskData['address'] ?? 'Location not specified';
    final String time = widget.taskData['time'] ?? 'Time not specified';
    final String price = '₹${widget.taskData['totalPrice'] ?? '0'}';

    String formattedDate = 'Date not available';
    final dynamic timestamp = widget.taskData['updatedAt'] ?? widget.taskData['createdAt'];
    if (timestamp is Timestamp) {
      formattedDate = DateFormat('EEEE, d MMMM yyyy').format(timestamp.toDate());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text('Task Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'BOOKING / #${bookingId.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey.shade500, 
                            fontSize: 11, 
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusPill(_status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title, 
                              style: const TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold, 
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Price tag badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5), // Light green
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.currency_rupee_rounded, size: 14, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Text(
                                    price.replaceAll('₹', '').trim(), 
                                    style: const TextStyle(
                                      color: Color(0xFF059669), 
                                      fontSize: 14, 
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FutureBuilder<DocumentSnapshot>(
                        future: widget.taskData['serviceId'] != null
                            ? FirebaseFirestore.instance.collection('services').doc(widget.taskData['serviceId']).get()
                            : null,
                        builder: (context, snap) {
                          String? imageUrl;
                          if (snap.hasData && snap.data != null) {
                            final svcData = snap.data!.data() as Map<String, dynamic>?;
                            imageUrl = svcData?['imageUrl'] as String?;
                          }
                          imageUrl ??= (widget.taskData['imagePath']?.toString().startsWith('http') == true)
                              ? widget.taskData['imagePath'] as String
                              : null;

                          return Container(
                            width: 95,
                            height: 95,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: const Color(0xFFF1F5F9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              image: imageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageUrl == null
                                ? const Center(
                                    child: Icon(Icons.miscellaneous_services_rounded, size: 36, color: Color(0xFFCBD5E1)),
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!_shouldHideCustomerAndLocation) ...[
              const SizedBox(height: 20),

              _buildSection(
                title: 'Customer Details',
                icon: Icons.person_outline_rounded,
                iconBgColor: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF7C3AED),
                child: (widget.taskData['userId'] == null || widget.taskData['userId'].toString().isEmpty)
                  ? const Text('Customer data not available')
                  : FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(widget.taskData['userId']).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(15.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Text('Error loading customer profile');
                        }

                        final userData = snapshot.data?.data() as Map<String, dynamic>?;
                        final String name = userData?['name'] ?? widget.taskData['userName'] ?? 'Customer';
                        final String? profilePic = userData?['profilePic'];

                        final String workerId = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final String userId = widget.taskData['userId'] ?? '';
                        String chatId = 'bookings/${widget.taskData['id']}';
                        if (userId.isNotEmpty) {
                          final List<String> ids = [workerId, userId]..sort();
                          chatId = 'direct_chats/${ids[0]}_${ids[1]}';
                        }

                        void navigateToChat() {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                providerName: name,
                                providerRole: widget.taskData['title'] ?? 'Customer',
                                bookingId: chatId,
                                isReadOnly: false,
                                avatarType: profilePic != null ? 'image' : 'icon',
                                avatarIcon: Icons.person,
                                avatarBgColor: primaryColor,
                                imageUrl: profilePic,
                                recipientId: userId,
                                recipientRole: 'user',
                              ),
                            ),
                          );
                        }

                        return InkWell(
                          onTap: navigateToChat,
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25, 
                                backgroundColor: const Color(0xFFEEF2FF),
                                backgroundImage: (profilePic != null && profilePic.isNotEmpty) ? NetworkImage(profilePic) : null,
                                child: (profilePic == null || profilePic.isEmpty) ? const Icon(Icons.person, color: Color(0xFF4F46E5)) : null,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name, 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: navigateToChat,
                                icon: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF4F46E5), size: 20),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => _openMap(address),
                child: _buildSection(
                  title: 'Service Location',
                  icon: Icons.location_on_outlined,
                  iconBgColor: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CUSTOMER ADDRESS',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  address,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _openMap(address),
                          icon: const Icon(Icons.directions_rounded, color: Colors.white),
                          label: const Text(
                            'NAVIGATE TO CUSTOMER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            _buildSection(
              title: 'Quick Actions',
              icon: Icons.bolt_rounded,
              iconBgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              child: Column(
                children: [
                  if (_status != 'Completed' && _status != 'Cancelled' && _status != 'Pending Verification') ...[
                    _buildActionButton(
                      'Start Service', 
                      Icons.play_arrow_rounded, 
                      _status == 'In Progress' ? Colors.grey : Colors.deepPurple, 
                      _status == 'In Progress' ? null : () => _showBeforeServiceDialog()
                    ),
                    const SizedBox(height: 12),
                    _hasUploadedProof
                        ? _buildActionButton(
                            'Continue to Payment', 
                            Icons.payment_rounded, 
                            Colors.green, 
                            () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WorkerPaymentScreen(taskData: widget.taskData),
                                ),
                              );
                              if (result == true && mounted) {
                                setState(() {
                                  _status = 'Pending Verification';
                                  _isPaid = true;
                                });
                              }
                            }
                          )
                        : _buildActionButton(
                            'Complete Service', 
                            Icons.check_circle_rounded, 
                            _status == 'In Progress' ? Colors.green : Colors.grey, 
                            _status == 'In Progress' ? () => _showCompleteServiceDialog() : null
                          ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      'Cancel Service', 
                      Icons.close_rounded, 
                      Colors.red, 
                      () => _updateStatus('Cancelled')
                    ),
                  ] else if (_status == 'Pending Verification') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: (_isPaid ? Colors.green : Colors.orange).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(_isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded, 
                               color: _isPaid ? Colors.green : Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isPaid 
                                  ? 'Payment Collected. Awaiting Admin Verification to finalize the booking.'
                                  : 'Awaiting Admin Verification. You can now proceed to collect the payment from the customer.',
                              style: TextStyle(color: _isPaid ? Colors.green : Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isPaid) ...[
                      const SizedBox(height: 12),
                      _buildActionButton(
                        'Continue to Payment', 
                        Icons.payment_rounded, 
                        primaryColor, 
                        () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkerPaymentScreen(taskData: widget.taskData),
                            ),
                          );
                          if (result == true && mounted) {
                            setState(() {
                              _status = 'Pending Verification';
                              _isPaid = true;
                            });
                          }
                        }
                      ),
                    ],
                  ] else ...[
                    _buildActionButton(
                      'Service Finished', 
                      Icons.done_all_rounded, 
                      Colors.grey, 
                      null
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 📅 Date & Time
            _buildSection(
              title: 'Date & Time',
              icon: Icons.calendar_today_rounded,
              iconBgColor: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFF43F5E),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SCHEDULED FOR', style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showOTPDialog() {
    final List<TextEditingController> controllers = List.generate(4, (index) => TextEditingController(text: '\u200B'));
    final List<FocusNode> focusNodes = List.generate(4, (index) => FocusNode());

    // Auto-focus the first text field on dialog build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNodes[0].canRequestFocus) {
        focusNodes[0].requestFocus();
        controllers[0].selection = TextSelection.fromPosition(
          TextPosition(offset: controllers[0].text.length),
        );
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify Service', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 4-digit OTP provided by the customer to start the service.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => SizedBox(
                width: 45,
                child: TextField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                  decoration: InputDecoration(
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 2)),
                  ),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      if (index > 0) {
                        controllers[index - 1].text = '\u200B';
                        focusNodes[index - 1].requestFocus();
                        controllers[index - 1].selection = TextSelection.fromPosition(
                          TextPosition(offset: controllers[index - 1].text.length),
                        );
                      }
                      controllers[index].text = '\u200B';
                      controllers[index].selection = TextSelection.fromPosition(
                        TextPosition(offset: controllers[index].text.length),
                      );
                    } else if (value.length > 1) {
                      final cleanDigit = value.replaceAll('\u200B', '').replaceAll(RegExp(r'[^0-9]'), '');
                      if (cleanDigit.isNotEmpty) {
                        final String newChar = cleanDigit.substring(cleanDigit.length - 1);
                        controllers[index].text = '\u200B' + newChar;
                        controllers[index].selection = TextSelection.fromPosition(
                          TextPosition(offset: controllers[index].text.length),
                        );
                        if (index < 3) {
                          focusNodes[index + 1].requestFocus();
                        }
                      } else {
                        controllers[index].text = '\u200B';
                        controllers[index].selection = TextSelection.fromPosition(
                          TextPosition(offset: controllers[index].text.length),
                        );
                      }
                    }
                  },
                ),
              )),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: _isUpdating ? null : () {
              String enteredOTP = controllers.map((e) => e.text.replaceAll('\u200B', '')).join();
              if (enteredOTP.length == 4) {
                _verifyOTP(enteredOTP);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isUpdating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('VERIFY & START'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOTP(String enteredOTP) async {
    Navigator.pop(context); // Close dialog
    
    try {
      final doc = await FirebaseFirestore.instance.collection('bookings').doc(widget.taskData['id']).get();
      final actualOTP = doc.data()?['otp']?.toString();
      
      if (actualOTP == enteredOTP) {
        await _updateStatus('In Progress');
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            title: const Text('OTP Verified!'),
            description: const Text('Service has been started successfully.'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      } else {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Verification Failed'),
            description: const Text('Invalid OTP. Please check with the customer.'),
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Error verifying OTP: $e'),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  Widget _buildSection({
    String? title, 
    IconData? icon,
    Color? iconBgColor,
    Color? iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor ?? const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon, 
                      color: iconColor ?? const Color(0xFF4F46E5), 
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  title, 
                  style: const TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, {Color? color, Color? textColor}) {
    Color bgColor = color ?? const Color(0xFFF1F5F9);
    Color txtColor = textColor ?? const Color(0xFF64748B);

    final String upperStatus = status.toUpperCase();

    if (upperStatus == 'IN PROGRESS' || upperStatus == 'COMPLETED') {
      bgColor = const Color(0xFFECFDF5);
      txtColor = const Color(0xFF059669);
    } else if (upperStatus == 'PENDING VERIFICATION') {
      bgColor = const Color(0xFFFFF7ED);
      txtColor = const Color(0xFFEA580C);
    } else if (upperStatus == 'CANCELLED') {
      bgColor = const Color(0xFFFEF2F2);
      txtColor = const Color(0xFFDC2626);
    } else if (upperStatus == 'CONFIRMED' || upperStatus == 'ASSIGNED') {
      bgColor = const Color(0xFFEEF2FF);
      txtColor = const Color(0xFF4F46E5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: txtColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }


  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback? onTap) {
    final bool isDisabled = onTap == null || color == Colors.grey;
    
    Color bgColor;
    Color borderColor;
    Color contentColor;
    
    if (isDisabled) {
      bgColor = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFE2E8F0);
      contentColor = const Color(0xFF94A3B8);
    } else if (color == Colors.green) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFFA7F3D0);
      contentColor = const Color(0xFF059669);
    } else if (color == Colors.red) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFCA5A5);
      contentColor = const Color(0xFFDC2626);
    } else {
      // Start / Continue Payment (Purple/indigo style)
      bgColor = const Color(0xFFEEF2FF);
      borderColor = const Color(0xFFC7D2FE);
      contentColor = const Color(0xFF4F46E5);
    }

    return InkWell(
      onTap: _isUpdating ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 1.2),
          color: bgColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUpdating && !isDisabled && color != Colors.red)
              SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: contentColor)
              )
            else ...[
              Icon(icon, color: contentColor, size: 22),
              const SizedBox(width: 12),
              Text(
                label, 
                style: TextStyle(
                  color: contentColor, 
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                )
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5,
    this.dashLength = 5,
    this.borderRadius = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    double distance = 0.0;
    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}





