import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'shop_waiting_approval_screen.dart';

class ShopOnboardingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialShopData;

  const ShopOnboardingScreen({super.key, this.initialShopData});

  @override
  ConsumerState<ShopOnboardingScreen> createState() => _ShopOnboardingScreenState();
}

class _ShopOnboardingScreenState extends ConsumerState<ShopOnboardingScreen> {
  static const primaryColor = Color(0xFF2029C5);
  static const secondaryIndigo = Color(0xFF4F46E5);
  static const accentEmerald = Color(0xFF10B981);
  static const bgLight = Color(0xFFF8FAFC);
  static const darkText = Color(0xFF0F172A);
  static const mutedText = Color(0xFF64748B);
  static const borderColor = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();

  // Prefilled / Basic Info Controllers
  late TextEditingController _ownerNameController;
  late TextEditingController _shopNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _serviceTypeController;

  // Location Controllers
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Photo & Documents Files
  File? _shopPhotoFile;
  String? _existingShopPhotoUrl;

  final Map<String, File> _legalDocFiles = {};
  final Map<String, String> _existingDocUrls = {};

  final List<Map<String, String>> _requiredLegalDocs = [
    {
      'key': 'tradeLicense',
      'title': 'Trade License / Shop Act Certificate',
      'desc': 'Municipal trade license or state shop & establishment act registration certificate.',
      'icon': 'verified_user',
    },
    {
      'key': 'gstCertificate',
      'title': 'GST Registration Certificate',
      'desc': 'Valid GSTIN certificate or registration document of the automotive workshop.',
      'icon': 'receipt_long',
    },
    {
      'key': 'ownerIdProof',
      'title': 'Owner ID Proof (Aadhaar / PAN)',
      'desc': 'Government-issued photo identification proof of the workshop owner.',
      'icon': 'badge',
    },
    {
      'key': 'addressProof',
      'title': 'Shop Address Proof / Electricity Bill',
      'desc': 'Recent electricity bill, commercial property tax receipt, or lease agreement.',
      'icon': 'domain',
    },
  ];

  bool _isLoading = true;
  bool _isDetectingLocation = false;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController();
    _shopNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _serviceTypeController = TextEditingController();

    _loadShopProfile();
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _serviceTypeController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadShopProfile() async {
    if (widget.initialShopData != null) {
      _applyShopData(widget.initialShopData!);
      setState(() => _isLoading = false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          _applyShopData(doc.data()!);
        } else {
          _emailController.text = user.email ?? '';
        }
      } catch (e) {
        debugPrint('Error loading shop profile: $e');
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _applyShopData(Map<String, dynamic> data) {
    _ownerNameController.text = (data['ownerName'] ?? data['name'] ?? '').toString();
    _shopNameController.text = (data['shopName'] ?? '').toString();
    _emailController.text = (data['email'] ?? '').toString();
    _phoneController.text = (data['phone'] ?? '').toString();
    _serviceTypeController.text = (data['serviceType'] ?? 'Car & Bike Servicing').toString();

    if (data['address'] != null) _addressController.text = data['address'].toString();
    if (data['latitude'] != null) _latitudeController.text = data['latitude'].toString();
    if (data['longitude'] != null) _longitudeController.text = data['longitude'].toString();

    if (data['shopPhoto'] is String && (data['shopPhoto'] as String).isNotEmpty) {
      _existingShopPhotoUrl = data['shopPhoto'];
    }

    if (data['documents'] is Map) {
      final docs = Map<String, dynamic>.from(data['documents']);
      docs.forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          _existingDocUrls[k] = v;
        }
      });
    }
  }

  // Validate only JPG and PNG
  bool _isAllowedImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  Future<void> _pickShopPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      if (!_isAllowedImage(picked.path)) {
        if (mounted) {
          CustomToast.error(context, 'Only JPG and PNG image files are allowed');
        }
        return;
      }

      setState(() {
        _shopPhotoFile = File(picked.path);
      });
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to select image: $e');
    }
  }

  Future<void> _pickLegalDoc(String docKey, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      if (!_isAllowedImage(picked.path)) {
        if (mounted) {
          CustomToast.error(context, 'Only JPG and PNG document images are allowed');
        }
        return;
      }

      setState(() {
        _legalDocFiles[docKey] = File(picked.path);
      });
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to pick document: $e');
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);

        final addr = await LocationService.getAddressFromLatLng(position);
        if (addr != null && _addressController.text.trim().isEmpty) {
          _addressController.text = addr;
        }

        if (mounted) CustomToast.success(context, 'Location coordinates detected!');
      }
    } catch (e) {
      if (mounted) CustomToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  int _calculateCompletedCount() {
    int count = 1; // Basic profile is ready
    if (_addressController.text.trim().isNotEmpty &&
        _latitudeController.text.trim().isNotEmpty &&
        _longitudeController.text.trim().isNotEmpty) {
      count++;
    }
    if (_shopPhotoFile != null || _existingShopPhotoUrl != null) {
      count++;
    }
    int docsCount = 0;
    for (final doc in _requiredLegalDocs) {
      final key = doc['key']!;
      if (_legalDocFiles.containsKey(key) || _existingDocUrls.containsKey(key)) {
        docsCount++;
      }
    }
    if (docsCount == _requiredLegalDocs.length) {
      count++;
    }
    return count;
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) {
      CustomToast.error(context, 'Please complete all required fields');
      return;
    }

    if (_shopPhotoFile == null && _existingShopPhotoUrl == null) {
      CustomToast.error(context, 'Please upload a clear storefront photo of your workshop');
      return;
    }

    // Check all required documents
    for (final doc in _requiredLegalDocs) {
      final key = doc['key']!;
      if (!_legalDocFiles.containsKey(key) && !_existingDocUrls.containsKey(key)) {
        CustomToast.error(context, 'Please upload ${doc['title']} (JPG/PNG)');
        return;
      }
    }

    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());
    if (lat == null || lng == null) {
      CustomToast.error(context, 'Please provide valid latitude and longitude coordinates');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomToast.error(context, 'User not authenticated');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload Shop Photo if newly picked
      String finalShopPhotoUrl = _existingShopPhotoUrl ?? '';
      if (_shopPhotoFile != null) {
        final uploaded = await CloudinaryService.uploadImage(
          _shopPhotoFile!,
          folder: 'shops/photos',
        );
        if (uploaded == null) throw 'Failed to upload shop photo to Cloudinary';
        finalShopPhotoUrl = uploaded;
      }

      // 2. Upload Legal Documents
      final Map<String, String> finalDocUrls = Map.from(_existingDocUrls);
      for (final entry in _legalDocFiles.entries) {
        final uploaded = await CloudinaryService.uploadImage(
          entry.value,
          folder: 'shops/documents',
        );
        if (uploaded == null) throw 'Failed to upload document (${entry.key}) to Cloudinary';
        finalDocUrls[entry.key] = uploaded;
      }

      // 3. Save to Firestore
      await ref.read(authViewModelProvider.notifier).submitShopOnboarding(
            uid: user.uid,
            address: _addressController.text.trim(),
            latitude: lat,
            longitude: lng,
            shopPhotoUrl: finalShopPhotoUrl,
            documents: finalDocUrls,
          );

      if (!mounted) return;

      CustomToast.success(context, 'Workshop details submitted for verification!');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ShopWaitingApprovalScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) CustomToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showImageSourceModal({
    required String title,
    required Function(ImageSource) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_a_photo_rounded, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(ImageSource.camera);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: bgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded, color: primaryColor, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Use camera',
                            style: TextStyle(fontSize: 11, color: mutedText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelected(ImageSource.gallery);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: bgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_rounded, color: secondaryIndigo, size: 30),
                          SizedBox(height: 8),
                          Text(
                            'Choose Gallery',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkText,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'JPG / PNG files',
                            style: TextStyle(fontSize: 11, color: mutedText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    final completedCount = _calculateCompletedCount();
    const totalSteps = 4;
    final progressPercent = completedCount / totalSteps;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Partner Verification',
              style: TextStyle(
                color: darkText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Complete workshop profile & KYC verification',
              style: TextStyle(
                color: mutedText,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Scrollable Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Step Tracker Card
                      _buildProgressHero(completedCount, totalSteps, progressPercent),
                      const SizedBox(height: 24),

                      // Section 1: Workshop Profile
                      _buildSectionHeader(
                        number: '1',
                        title: 'Basic Workshop Details',
                        subtitle: 'Profile synced from registration',
                        icon: Icons.storefront_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildWorkshopProfileCard(),
                      const SizedBox(height: 24),

                      // Section 2: Address & Location
                      _buildSectionHeader(
                        number: '2',
                        title: 'Workshop Location & GPS',
                        subtitle: 'Help nearby customers find your garage accurately',
                        icon: Icons.location_on_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildLocationCard(),
                      const SizedBox(height: 24),

                      // Section 3: Storefront Photo
                      _buildSectionHeader(
                        number: '3',
                        title: 'Workshop Storefront Photo',
                        subtitle: 'Clear front photo showing signage and workshop entrance',
                        icon: Icons.add_a_photo_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildStorefrontPhotoCard(),
                      const SizedBox(height: 24),

                      // Section 4: Legal KYC Documents
                      _buildSectionHeader(
                        number: '4',
                        title: 'Legal Documents & KYC',
                        subtitle: 'Upload valid government registration documents',
                        icon: Icons.verified_user_rounded,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: primaryColor, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Only JPG & PNG images supported (Max 5MB each). Documents are 256-bit encrypted.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ..._requiredLegalDocs.map((doc) => _buildDocUploadCard(doc)),
                      const SizedBox(height: 16),

                      // Trust & Security Notice Banner
                      _buildTrustBanner(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Fixed Bottom Submit CTA Container
              _buildBottomActionContainer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHero(int completed, int total, double percent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, secondaryIndigo],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner Verification Status',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completed of $total Steps Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: percent == 1.0 ? accentEmerald : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '${(percent * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 1.0 ? accentEmerald : primaryColor,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [primaryColor, secondaryIndigo]),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkshopProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.storefront_rounded,
            label: 'Workshop Name',
            value: _shopNameController.text.isNotEmpty ? _shopNameController.text : 'Not provided',
            isPrimary: true,
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.person_rounded,
            label: 'Owner Name',
            value: _ownerNameController.text.isNotEmpty ? _ownerNameController.text : 'Not provided',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Registered Email',
            value: _emailController.text.isNotEmpty ? _emailController.text : 'Not provided',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Contact Number',
            value: _phoneController.text.isNotEmpty ? _phoneController.text : 'Not provided',
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          _buildInfoRow(
            icon: Icons.build_circle_outlined,
            label: 'Service Specialization',
            value: _serviceTypeController.text.isNotEmpty ? _serviceTypeController.text : 'Car & Bike Servicing',
            badgeColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isPrimary = false,
    Color? badgeColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: primaryColor),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                color: darkText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter full workshop address' : null,
            decoration: InputDecoration(
              labelText: 'Full Workshop Address *',
              hintText: 'e.g. Plot No 12, Main MG Road, Industrial Area, Sector 5',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Icon(Icons.business_rounded, color: primaryColor, size: 20),
              ),
              filled: true,
              fillColor: bgLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  decoration: InputDecoration(
                    labelText: 'Latitude *',
                    hintText: 'e.g. 28.6139',
                    prefixIcon: const Icon(Icons.explore_rounded, color: primaryColor, size: 18),
                    filled: true,
                    fillColor: bgLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  decoration: InputDecoration(
                    labelText: 'Longitude *',
                    hintText: 'e.g. 77.2090',
                    prefixIcon: const Icon(Icons.explore_outlined, color: secondaryIndigo, size: 18),
                    filled: true,
                    fillColor: bgLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isDetectingLocation ? null : _detectLocation,
              icon: _isDetectingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                    )
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(
                _isDetectingLocation ? 'Detecting Realtime GPS...' : 'Auto-Detect Current GPS Coordinates',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: const BorderSide(color: primaryColor, width: 1.2),
                backgroundColor: primaryColor.withValues(alpha: 0.04),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorefrontPhotoCard() {
    final bool hasPhoto = _shopPhotoFile != null || _existingShopPhotoUrl != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasPhoto ? accentEmerald.withValues(alpha: 0.3) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPhoto) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _shopPhotoFile != null
                      ? Image.file(
                          _shopPhotoFile!,
                          width: double.infinity,
                          height: 190,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          _existingShopPhotoUrl!,
                          width: double.infinity,
                          height: 190,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: accentEmerald, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Ready to Upload',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              width: double.infinity,
              height: 130,
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 40, color: mutedText),
                  SizedBox(height: 8),
                  Text(
                    'No Storefront Photo Selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ensure signboard & workshop gate are visible',
                    style: TextStyle(fontSize: 11, color: mutedText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showImageSourceModal(
                    title: 'Upload Storefront Photo',
                    onSelected: (source) => _pickShopPhoto(source),
                  ),
                  icon: Icon(hasPhoto ? Icons.edit_rounded : Icons.camera_alt_rounded, size: 16),
                  label: Text(
                    hasPhoto ? 'Change Photo' : 'Upload Photo (JPG/PNG)',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasPhoto ? const Color(0xFFF1F5F9) : primaryColor,
                    foregroundColor: hasPhoto ? darkText : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (hasPhoto && _shopPhotoFile != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _shopPhotoFile = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocUploadCard(Map<String, String> doc) {
    final key = doc['key']!;
    final title = doc['title']!;
    final desc = doc['desc']!;

    final hasNewFile = _legalDocFiles.containsKey(key);
    final hasExistingUrl = _existingDocUrls.containsKey(key);
    final isUploaded = hasNewFile || hasExistingUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUploaded ? const Color(0xFFA7F3D0) : borderColor,
          width: isUploaded ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUploaded
                      ? const Color(0xFFECFDF5)
                      : primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isUploaded ? Icons.verified_rounded : Icons.description_rounded,
                  size: 18,
                  color: isUploaded ? accentEmerald : primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: mutedText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUploaded ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUploaded ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUploaded ? Icons.check_circle_rounded : Icons.pending_outlined,
                      size: 12,
                      color: isUploaded ? accentEmerald : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isUploaded ? 'UPLOADED' : 'REQUIRED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isUploaded ? const Color(0xFF065F46) : const Color(0xFF92400E),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Preview thumbnail if available
          if (hasNewFile) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                _legalDocFiles[key]!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ] else if (hasExistingUrl) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _existingDocUrls[key]!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImageSourceModal(
                    title: 'Upload $title',
                    onSelected: (source) => _pickLegalDoc(key, source),
                  ),
                  icon: Icon(
                    isUploaded ? Icons.sync_rounded : Icons.upload_file_rounded,
                    size: 15,
                  ),
                  label: Text(
                    isUploaded ? 'Replace Document' : 'Choose Document (JPG/PNG)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (hasNewFile) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _legalDocFiles.remove(key);
                    });
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_rounded, color: Color(0xFF475569), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypted Partner KYC Verification',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Your business and KYC documents are encrypted and audited solely for partner onboarding verification. The approval turnaround time is 24 to 48 hours.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionContainer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: primaryColor.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Uploading Documents & Submitting...',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Submit Verification for Approval',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
