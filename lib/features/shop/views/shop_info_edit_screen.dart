import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';

class ShopInfoEditScreen extends StatefulWidget {
  const ShopInfoEditScreen({super.key});

  @override
  State<ShopInfoEditScreen> createState() => _ShopInfoEditScreenState();
}

class _ShopInfoEditScreenState extends State<ShopInfoEditScreen> {
  static const primaryColor = Color(0xFF2029C5);

  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _selectedServiceType = 'Car & Bike Servicing';
  final List<String> _serviceTypes = [
    'Car & Bike Servicing',
    'Car Servicing & Wash',
    'Bike Servicing & Repair',
    'Full Auto Care & Detailing',
  ];

  File? _newShopPhotoFile;
  String? _existingShopPhotoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetectingLocation = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadShopData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _shopNameController.text = (data['shopName'] ?? data['businessName'] ?? '').toString();
        _ownerNameController.text = (data['ownerName'] ?? data['name'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        _emailController.text = (data['email'] ?? user.email ?? '').toString();
        _addressController.text = (data['address'] ?? data['shopAddress'] ?? '').toString();
        
        if (data['latitude'] != null) _latitudeController.text = data['latitude'].toString();
        if (data['longitude'] != null) _longitudeController.text = data['longitude'].toString();

        final sType = data['serviceType']?.toString();
        if (sType != null && _serviceTypes.contains(sType)) {
          _selectedServiceType = sType;
        }

        if (data['shopPhoto'] is String && (data['shopPhoto'] as String).isNotEmpty) {
          _existingShopPhotoUrl = data['shopPhoto'];
        }
      } else {
        _emailController.text = user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error loading shop info: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickShopPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final lower = picked.path.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png')) {
        if (mounted) {
          CustomToast.warning(context, 'Please upload a JPG or PNG image only.');
        }
        return;
      }

      setState(() {
        _newShopPhotoFile = File(picked.path);
      });
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to pick image: $e');
      }
    }
  }

  void _showPhotoOptions() {
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
                'Change Workshop Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickShopPhoto(ImageSource.camera);
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
                        _pickShopPhoto(ImageSource.gallery);
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

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final address = await LocationService.getAddressFromLatLng(pos);
        setState(() {
          if (address != null && address.isNotEmpty) {
            _addressController.text = address;
          }
          _latitudeController.text = pos.latitude.toString();
          _longitudeController.text = pos.longitude.toString();
        });
        if (mounted) {
          CustomToast.success(context, 'Workshop location detected successfully!');
        }
      } else {
        if (mounted) {
          CustomToast.warning(context, 'Could not detect location. Please check GPS permissions.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Error detecting location: $e');
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      String? photoUrl = _existingShopPhotoUrl;

      // 1. Upload new photo if changed
      if (_newShopPhotoFile != null) {
        final uploaded = await CloudinaryService.uploadImage(_newShopPhotoFile!, folder: 'shop_photos');
        if (uploaded != null) {
          photoUrl = uploaded;
        }
      }

      final double? lat = double.tryParse(_latitudeController.text.trim());
      final double? lng = double.tryParse(_longitudeController.text.trim());

      final updateData = <String, dynamic>{
        'shopName': _shopNameController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'name': _ownerNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'serviceType': _selectedServiceType,
        'address': _addressController.text.trim(),
        'shopAddress': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (lat != null && lng != null) {
        updateData['latitude'] = lat;
        updateData['longitude'] = lng;
      }
      if (photoUrl != null) {
        updateData['shopPhoto'] = photoUrl;
      }

      await FirebaseFirestore.instance.collection('shops').doc(user.uid).set(updateData, SetOptions(merge: true));

      if (mounted) {
        CustomToast.success(context, 'Workshop information updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Error saving updates: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          'Edit Shop Information',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop Photo Header
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: ClipOval(
                                child: _newShopPhotoFile != null
                                    ? Image.file(_newShopPhotoFile!, fit: BoxFit.cover, width: 100, height: 100)
                                    : (_existingShopPhotoUrl != null && _existingShopPhotoUrl!.isNotEmpty)
                                        ? Image.network(
                                            _existingShopPhotoUrl!,
                                            fit: BoxFit.cover,
                                            width: 100,
                                            height: 100,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.storefront_rounded,
                                              size: 50,
                                              color: primaryColor,
                                            ),
                                          )
                                        : const Icon(Icons.storefront_rounded, size: 50, color: primaryColor),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _showPhotoOptions,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _showPhotoOptions,
                          child: const Text(
                            'Change Shop Photo',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Basic Details Card
                      _buildSectionContainer(
                        title: 'Workshop Details',
                        icon: Icons.business_rounded,
                        children: [
                          _buildInputField(
                            controller: _shopNameController,
                            label: 'Workshop / Shop Name',
                            hintText: 'e.g. Speed Wash & Auto Care',
                            icon: Icons.storefront_outlined,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter shop name' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _ownerNameController,
                            label: 'Owner Full Name',
                            hintText: 'e.g. John Doe',
                            icon: Icons.person_outline,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter owner name' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _phoneController,
                            label: 'Contact Phone Number',
                            hintText: 'e.g. +91 9876543210',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter phone number' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _emailController,
                            label: 'Email Address (Read-only)',
                            hintText: 'shop@domain.com',
                            icon: Icons.email_outlined,
                            readOnly: true,
                          ),
                          const SizedBox(height: 14),
                          // Service Type Dropdown
                          const Text('Primary Service Focus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedServiceType,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
                                items: _serviceTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedServiceType = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Workshop Address & GPS Card
                      _buildSectionContainer(
                        title: 'Location & Address',
                        icon: Icons.location_on_outlined,
                        children: [
                          _buildInputField(
                            controller: _addressController,
                            label: 'Workshop Physical Address',
                            hintText: 'Street, Landmark, City, State, PIN',
                            icon: Icons.map_outlined,
                            maxLines: 2,
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter shop address' : null,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isDetectingLocation ? null : _detectLocation,
                            icon: _isDetectingLocation
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                                : const Icon(Icons.my_location_rounded, size: 18, color: primaryColor),
                            label: Text(
                              _isDetectingLocation ? 'Detecting GPS...' : 'Auto-Detect Current GPS Location',
                              style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInputField(
                                  controller: _latitudeController,
                                  label: 'Latitude',
                                  hintText: '12.9716',
                                  icon: Icons.explore_outlined,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInputField(
                                  controller: _longitudeController,
                                  label: 'Longitude',
                                  hintText: '77.5946',
                                  icon: Icons.explore_outlined,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Save Workshop Changes',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
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
            children: [
              Icon(icon, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
