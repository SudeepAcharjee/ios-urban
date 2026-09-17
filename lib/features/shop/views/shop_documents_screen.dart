import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/custom_toast.dart';

class ShopDocumentsScreen extends StatefulWidget {
  const ShopDocumentsScreen({super.key});

  @override
  State<ShopDocumentsScreen> createState() => _ShopDocumentsScreenState();
}

class _ShopDocumentsScreenState extends State<ShopDocumentsScreen> {
  static const primaryColor = Color(0xFF2029C5);
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _documentTypes = [
    {
      'key': 'tradeLicense',
      'title': 'Trade License / Shop Act Certificate',
      'desc': 'Government issued trade license or shop registration certificate',
    },
    {
      'key': 'gstCertificate',
      'title': 'GST Registration Certificate',
      'desc': 'Valid GST registration document for the workshop',
    },
    {
      'key': 'ownerIdProof',
      'title': 'Owner ID Proof (Aadhaar / PAN)',
      'desc': 'Government issued photo identity of shop owner',
    },
    {
      'key': 'addressProof',
      'title': 'Shop Address Proof / Electricity Bill',
      'desc': 'Recent electricity bill or rent agreement of the shop',
    },
  ];

  Map<String, String> _existingDocs = {};
  final Map<String, File> _newDocFiles = {};
  final Map<String, bool> _isUploadingMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['documents'] is Map) {
          final docsMap = Map<String, dynamic>.from(data['documents']);
          final Map<String, String> formatted = {};
          docsMap.forEach((k, v) {
            if (v is String && v.isNotEmpty) {
              formatted[k] = v;
            }
          });
          if (mounted) {
            setState(() {
              _existingDocs = formatted;
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading shop documents: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  bool _isAllowedImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  Future<void> _pickDocument(String docKey, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      if (!_isAllowedImage(picked.path)) {
        if (mounted) {
          CustomToast.warning(context, 'Please upload a JPG or PNG image only.');
        }
        return;
      }

      final file = File(picked.path);
      setState(() {
        _newDocFiles[docKey] = file;
      });

      // Automatically upload immediately for convenience
      await _uploadSingleDocument(docKey, file);
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _uploadSingleDocument(String docKey, File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploadingMap[docKey] = true;
    });

    try {
      final uploadedUrl = await CloudinaryService.uploadImage(file, folder: 'shop_documents');
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        // Update local state
        setState(() {
          _existingDocs[docKey] = uploadedUrl;
          _newDocFiles.remove(docKey);
        });

        // Save directly to Firestore
        await FirebaseFirestore.instance.collection('shops').doc(user.uid).set({
          'documents': {
            docKey: uploadedUrl,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          CustomToast.success(context, 'Document updated and saved successfully!');
        }
      } else {
        if (mounted) {
          CustomToast.error(context, 'Cloud upload failed. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Error updating document: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMap[docKey] = false;
        });
      }
    }
  }

  void _showImageSourcePicker(String docKey) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upload Legal Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Select document source (JPG or PNG supported)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickDocument(docKey, ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_outlined, color: primaryColor),
                      label: const Text('Camera', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickDocument(docKey, ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
                      label: const Text('Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewFullScreenImage(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 250,
                        child: Center(
                          child: Text(
                            'Failed to load document preview',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text(
          'Verified Documents',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Summary Card with Verification Status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Legal Compliance & Verification',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your workshop documents are verified by the platform. You can update or replace any document below if renewed or updated.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Uploaded Documents',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 12),

                    // Documents List
                    for (final doc in _documentTypes) ...[
                      _buildDocumentCard(doc),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocumentCard(Map<String, String> doc) {
    final String key = doc['key']!;
    final String title = doc['title']!;
    final String desc = doc['desc']!;

    final String? uploadedUrl = _existingDocs[key];
    final File? localFile = _newDocFiles[key];
    final bool isUploading = _isUploadingMap[key] == true;
    final bool hasDoc = (uploadedUrl != null && uploadedUrl.isNotEmpty) || localFile != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hasDoc ? const Color(0xFFE2E8F0) : Colors.amber.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasDoc ? const Color(0xFFECFDF5) : Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasDoc ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: hasDoc ? const Color(0xFF10B981) : Colors.amber.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasDoc ? const Color(0xFFECFDF5) : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasDoc ? 'VERIFIED' : 'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: hasDoc ? const Color(0xFF059669) : Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Preview & Action Box
            if (isUploading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: primaryColor, strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text(
                      'Uploading & Verifying Document...',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              )
            else if (hasDoc)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Document Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade100,
                        child: localFile != null
                            ? Image.file(localFile, fit: BoxFit.cover)
                            : (uploadedUrl != null && uploadedUrl.isNotEmpty)
                                ? Image.network(
                                    uploadedUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.description_outlined,
                                      color: primaryColor,
                                      size: 30,
                                    ),
                                  )
                                : const Icon(Icons.description_outlined, color: primaryColor, size: 30),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Document Active',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          if (uploadedUrl != null && uploadedUrl.isNotEmpty)
                            GestureDetector(
                              onTap: () => _viewFullScreenImage(uploadedUrl, title),
                              child: const Text(
                                'Tap to view full document',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            )
                          else
                            const Text(
                              'Ready to upload',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    // Replace Button
                    ElevatedButton.icon(
                      onPressed: () => _showImageSourcePicker(key),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Replace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Upload Button Box
              InkWell(
                onTap: () => _showImageSourcePicker(key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file_rounded, color: primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Upload Document (JPG / PNG)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
