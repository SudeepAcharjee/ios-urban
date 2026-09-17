import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toastification/toastification.dart';
import '../../../core/services/cloudinary_service.dart';
import 'worker_disabled_overlay.dart';


class WorkerKycScreen extends StatefulWidget {
  final bool showAppBar;
  const WorkerKycScreen({super.key, this.showAppBar = false});

  @override
  State<WorkerKycScreen> createState() => _WorkerKycScreenState();
}

class _WorkerKycScreenState extends State<WorkerKycScreen> {
  static const primaryColor = Color(0xFF2029C5);

  bool _loading = true;
  bool _submitting = false;

  // Dynamic from Firestore kyc_settings/config.requiredDocs
  List<String> _requiredDocs = [];

  // Key = docName (e.g. "Aadhaar Front"), value = local File
  final Map<String, File> _pickedFiles = {};

  // Key = docName, value = already-uploaded URL
  final Map<String, String> _existingUrls = {};

  // Existing KYC submission metadata
  Map<String, dynamic>? _existingKyc;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadConfig(), _loadExistingKyc()]);
    if (mounted) setState(() => _loading = false);
  }

  /// Fetch required doc list from kyc_settings/config
  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kyc_settings')
          .doc('config')
          .get();
      final raw = doc.data()?['requiredDocs'];
      if (raw is List) {
        _requiredDocs = raw.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    // Fallback if collection not set up yet
    if (_requiredDocs.isEmpty) {
      _requiredDocs = ['Aadhaar Front', 'Aadhaar Back', 'PAN Card', 'Selfie'];
    }
  }

  /// Fetch worker's existing KYC submission
  Future<void> _loadExistingKyc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kyc_submissions')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _existingKyc = data;

        // Restore uploaded URLs for each doc
        final docs = data['documents'] as Map<String, dynamic>? ?? {};
        docs.forEach((key, value) {
          if (value is String) _existingUrls[key] = value;
        });


      }
    } catch (_) {}
  }

  Future<void> _pickImage(String docName) async {
    final source = await _showSourceDialog();
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() => _pickedFiles[docName] = File(picked.path));
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Choose Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _sourceOption(Icons.camera_alt_rounded, 'Camera', primaryColor,
                      () => Navigator.pop(context, ImageSource.camera))),
                  const SizedBox(width: 14),
                  Expanded(child: _sourceOption(Icons.photo_library_rounded, 'Gallery', Colors.purple,
                      () => Navigator.pop(context, ImageSource.gallery))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Ensure every required doc has been uploaded (either existing or newly picked)
    final missing = _requiredDocs.where((doc) =>
        !_existingUrls.containsKey(doc) && !_pickedFiles.containsKey(doc)).toList();

    if (missing.isNotEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        title: const Text('Missing Documents'),
        description: Text('Please upload: ${missing.join(', ')}'),
        autoCloseDuration: const Duration(seconds: 4),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final folder = 'worker_kyc/$uid';

      // Build final docs map: start from existing, overwrite any newly picked
      final Map<String, String> finalDocs = Map.from(_existingUrls);

      for (final docName in _pickedFiles.keys) {
        final url = await CloudinaryService.uploadImage(_pickedFiles[docName]!, folder: folder);
        if (url == null) throw Exception('Upload failed for: $docName');
        finalDocs[docName] = url;
      }

      // Fetch worker name and email for admin-facing submission record
      final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
      final workerName = workerDoc.data()?['name'] ?? workerDoc.data()?['fullName'] ?? 'Unknown';
      final workerEmail = workerDoc.data()?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? 'Unknown';

      final submissionData = {
        'workerId':    uid,
        'workerName':  workerName,
        'workerEmail': workerEmail,
        'documents':   finalDocs,
        'status':      'Pending',
        'submittedAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();

      // 1. Save inside worker subcollection (worker's own copy)
      final workerKycRef = FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .collection('kyc')
          .doc('details');
      batch.set(workerKycRef, submissionData, SetOptions(merge: true));

      // 2. Save to top-level kyc_submissions (admin review collection)
      final submissionRef = FirebaseFirestore.instance
          .collection('kyc_submissions')
          .doc(uid); // uid as doc ID = one record per worker, overwritten on resubmit
      batch.set(submissionRef, submissionData, SetOptions(merge: true));

      // 3. Mirror kycStatus on the top-level worker doc for quick reads
      final workerRef = FirebaseFirestore.instance.collection('workers').doc(uid);
      batch.update(workerRef, {'kycStatus': 'Pending'});

      await batch.commit();

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('KYC Submitted!'),
          description: const Text('Your documents are under review. We\'ll notify you once verified.'),
          autoCloseDuration: const Duration(seconds: 5),
        );
        setState(() {
          _existingUrls.addAll(finalDocs);
          _pickedFiles.clear();
          _existingKyc = {...?_existingKyc, 'status': 'Pending'};
        });
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Submission Failed'),
          description: Text(e.toString()),
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.black, size: 16),
                ),
              ),
              title: const Text('Identity Verification',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
              centerTitle: true,
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner & Title
                  _buildHeader(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          const Text(
                            'REQUIRED DOCUMENTS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Document List
                          ...List.generate(_requiredDocs.length, (i) {
                            final docName = _requiredDocs[i];
                            final status =
                                (_existingKyc?['status'] as String?)?.toLowerCase();
                            final canEdit =
                                status != 'approved' && status != 'pending';
                            return _buildModernDocTile(
                              docName: docName,
                              localFile: _pickedFiles[docName],
                              existingUrl: _existingUrls[docName],
                              canEdit: canEdit,
                              onTap: canEdit ? () => _pickImage(docName) : null,
                            );
                          }),

                          const SizedBox(height: 40),

                          // Submit button
                          if ((_existingKyc?['status'] as String?)?.toLowerCase() !=
                                  'approved' &&
                              (_existingKyc?['status'] as String?)?.toLowerCase() !=
                                  'pending') ...[
                            _buildSubmitButton(),
                            const SizedBox(height: 20),
                            const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock_rounded,
                                      size: 14, color: Colors.grey),
                                  SizedBox(width: 6),
                                  Text(
                                    'Secure 256-bit SSL encryption',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
      const PendingCashPaymentOverlay(),
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _buildHeader() {
    final status = (_existingKyc?['status'] as String?)?.toLowerCase();
    
    Color statusColor = primaryColor;
    String statusTitle = 'Complete Your KYC';
    String statusSub = 'Verify your identity to start receiving tasks';
    IconData statusIcon = Icons.verified_user_outlined;

    if (status == 'approved') {
      statusColor = Colors.green;
      statusTitle = 'Verification Complete';
      statusSub = 'Your identity has been successfully verified';
      statusIcon = Icons.verified_rounded;
    } else if (status == 'pending') {
      statusColor = Colors.orange;
      statusTitle = 'Verification Pending';
      statusSub = 'Our team is currently reviewing your documents';
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusTitle = 'Verification Failed';
      statusSub = _existingKyc?['rejectionReason'] ?? 'Please update your documents';
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(25, 30, 25, 40),
      width: double.infinity,
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(statusIcon, color: statusColor, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            statusTitle,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusSub,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDocTile({
    required String docName,
    required File? localFile,
    required String? existingUrl,
    required bool canEdit,
    required VoidCallback? onTap,
  }) {
    final hasImage = localFile != null || existingUrl != null;
    
    IconData docIcon = Icons.description_outlined;
    final lower = docName.toLowerCase();
    if (lower.contains('selfie')) docIcon = Icons.face_rounded;
    else if (lower.contains('front')) docIcon = Icons.badge_outlined;
    else if (lower.contains('back')) docIcon = Icons.credit_card_outlined;
    else if (lower.contains('pan')) docIcon = Icons.account_balance_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasImage ? primaryColor.withOpacity(0.2) : Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: hasImage ? primaryColor.withOpacity(0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: localFile != null
                              ? Image.file(localFile, fit: BoxFit.cover)
                              : Image.network(existingUrl!, fit: BoxFit.cover),
                        )
                      : Icon(docIcon, color: Colors.grey[400], size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasImage ? 'Document uploaded' : 'Not uploaded yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasImage ? primaryColor : Colors.grey[500],
                          fontWeight: hasImage ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasImage ? Colors.grey[50] : primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      hasImage ? 'Change' : 'Upload',
                      style: TextStyle(
                        color: hasImage ? Colors.grey[600] : primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Text(
                'Submit for Verification',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
