import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';

class ShopAddServiceScreen extends ConsumerStatefulWidget {
  const ShopAddServiceScreen({super.key});

  @override
  ConsumerState<ShopAddServiceScreen> createState() => _ShopAddServiceScreenState();
}

class _ShopAddServiceScreenState extends ConsumerState<ShopAddServiceScreen> {
  static const primaryColor = Color(0xFF2029C5);
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _serviceTimeController = TextEditingController(text: '30–45 Minutes');
  final _shortDescController = TextEditingController();
  final _longDescController = TextEditingController();
  final _priceController = TextEditingController();
  final _oldPriceController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController(text: '20');

  // Temporary item inputs for What's Included / Not Included
  final _includedItemController = TextEditingController();
  final _notIncludedItemController = TextEditingController();

  final List<String> _whatsIncluded = [];
  final List<String> _whatsNotIncluded = [];

  // Category State
  List<Map<String, String>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // Image State
  File? _coverImageFile;
  final List<File> _galleryFiles = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isDetectingLocation = false;
  bool _isSubmitting = false;

  // Shop Owner Info for reference
  String _shopName = '';
  String _ownerName = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serviceTimeController.dispose();
    _shortDescController.dispose();
    _longDescController.dispose();
    _priceController.dispose();
    _oldPriceController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _includedItemController.dispose();
    _notIncludedItemController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Fetch Categories from Firestore
      final catSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('name')
          .get();

      _categories = catSnapshot.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': (data['name'] ?? '').toString(),
        };
      }).where((c) => c['name']!.isNotEmpty).toList();

      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first['id'];
        _selectedCategoryName = _categories.first['name'];
      }

      // 2. Prefill shop profile info (address, coordinates, owner phone)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
        if (shopDoc.exists && shopDoc.data() != null) {
          final data = shopDoc.data()!;
          _shopName = (data['shopName'] ?? '').toString();
          _ownerName = (data['ownerName'] ?? data['name'] ?? '').toString();
          _phone = (data['phone'] ?? '').toString();
          if (data['address'] != null) _addressController.text = data['address'].toString();
          if (data['latitude'] != null) _latController.text = data['latitude'].toString();
          if (data['longitude'] != null) _lngController.text = data['longitude'].toString();

          // Try to match shop's serviceType to category
          final sType = (data['serviceType'] ?? '').toString().toLowerCase();
          final matchingCat = _categories.firstWhere(
            (c) => sType.contains(c['name']!.toLowerCase()) || c['name']!.toLowerCase().contains(sType),
            orElse: () => _categories.first,
          );
          _selectedCategoryId = matchingCat['id'];
          _selectedCategoryName = matchingCat['name'];
        }
      }
    } catch (e) {
      debugPrint('Error loading initial data for add service: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isAllowedImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      if (!_isAllowedImage(picked.path)) {
        if (mounted) CustomToast.error(context, 'Only JPG and PNG images are allowed');
        return;
      }
      setState(() => _coverImageFile = File(picked.path));
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to pick image: $e');
    }
  }

  Future<void> _pickGalleryImages() async {
    try {
      final pickedList = await _picker.pickMultiImage(imageQuality: 85);
      if (pickedList.isEmpty) return;

      final validFiles = <File>[];
      for (final p in pickedList) {
        if (_isAllowedImage(p.path)) {
          validFiles.add(File(p.path));
        }
      }

      if (validFiles.length < pickedList.length && mounted) {
        CustomToast.info(context, 'Some files were skipped: Only JPG and PNG are accepted');
      }

      setState(() {
        _galleryFiles.addAll(validFiles);
      });
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to pick gallery images: $e');
    }
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _latController.text = pos.latitude.toStringAsFixed(6);
        _lngController.text = pos.longitude.toStringAsFixed(6);
        final addr = await LocationService.getAddressFromLatLng(pos);
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

  void _addIncludedItem() {
    final text = _includedItemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _whatsIncluded.add(text);
      _includedItemController.clear();
    });
  }

  void _addNotIncludedItem() {
    final text = _notIncludedItemController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _whatsNotIncluded.add(text);
      _notIncludedItemController.clear();
    });
  }

  Future<void> _submitService() async {
    if (!_formKey.currentState!.validate()) return;

    if (_coverImageFile == null) {
      CustomToast.error(context, 'Please upload a cover image for the service');
      return;
    }

    final price = _priceController.text.trim();
    if (double.tryParse(price) == null || double.parse(price) <= 0) {
      CustomToast.error(context, 'Please enter a valid service price');
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      CustomToast.error(context, 'Please enter valid latitude and longitude coordinates');
      return;
    }

    final radius = int.tryParse(_radiusController.text.trim()) ?? 20;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomToast.error(context, 'User not authenticated');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload Cover Image to Cloudinary
      final coverUrl = await CloudinaryService.uploadImage(
        _coverImageFile!,
        folder: 'services',
      );
      if (coverUrl == null) throw 'Failed to upload cover image';

      // 2. Upload Gallery Images to Cloudinary
      final galleryUrls = <String>[];
      for (final f in _galleryFiles) {
        final url = await CloudinaryService.uploadImage(f, folder: 'services/gallery');
        if (url != null) galleryUrls.add(url);
      }

      // 3. Write to Firestore 'verify-service' collection
      await FirebaseFirestore.instance.collection('verify-service').add({
        'name': _nameController.text.trim(),
        'category': _selectedCategoryName ?? 'Workshop',
        'categoryId': _selectedCategoryId ?? '',
        'price': price,
        'oldPrice': _oldPriceController.text.trim(),
        'serviceTime': _serviceTimeController.text.trim(),
        'shortDescription': _shortDescController.text.trim(),
        'longDescription': _longDescController.text.trim(),
        'image': coverUrl,
        'gallery': galleryUrls,
        'address': _addressController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'whatsIncluded': _whatsIncluded,
        'whatsNotIncluded': _whatsNotIncluded,
        'status': 'Pending',
        'ownerId': user.uid,
        'shopName': _shopName,
        'ownerName': _ownerName,
        'phone': _phone,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      CustomToast.success(context, 'Service submitted for admin approval!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) CustomToast.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New Service',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Info Note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Services are reviewed by our admin team before appearing live to customers.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // 1. Service Information
                // -------------------------------------------------------------
                _buildSectionTitle('1. Service Information', Icons.build_circle_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter service name' : null,
                    decoration: _inputDecoration(
                      label: 'Service Name',
                      hint: 'e.g. Synthetic Engine Oil & Filter Change',
                      icon: Icons.title_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: _inputDecoration(
                      label: 'Category',
                      hint: 'Select Category',
                      icon: Icons.category_outlined,
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat['id'],
                        child: Text(cat['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = _categories.firstWhere((c) => c['id'] == val);
                        setState(() {
                          _selectedCategoryId = val;
                          _selectedCategoryName = found['name'];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Service Duration
                  TextFormField(
                    controller: _serviceTimeController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter duration' : null,
                    decoration: _inputDecoration(
                      label: 'Service Duration',
                      hint: 'e.g. 30–45 Minutes',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Short Description
                  TextFormField(
                    controller: _shortDescController,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter short summary' : null,
                    decoration: _inputDecoration(
                      label: 'Short Description',
                      hint: 'A brief summary of the service (displayed in lists)',
                      icon: Icons.short_text_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Long Description
                  TextFormField(
                    controller: _longDescController,
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter full description' : null,
                    decoration: _inputDecoration(
                      label: 'Long Description',
                      hint: 'Comprehensive explanation of what this service covers, tools used, etc.',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // 2. Service Cover Image & Gallery
                // -------------------------------------------------------------
                _buildSectionTitle('2. Cover Image & Gallery (JPG / PNG)', Icons.add_a_photo_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  const Text(
                    'Main Cover Photo (Required)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),

                  if (_coverImageFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_coverImageFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickCoverImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 15),
                          label: const Text('Camera (JPG/PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickCoverImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 15),
                          label: const Text('Gallery (JPG/PNG)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Additional Gallery Images
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Additional Gallery Photos (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      TextButton.icon(
                        onPressed: _pickGalleryImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                        label: const Text('Add Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_galleryFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 85,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _galleryFiles.length,
                        itemBuilder: (context, idx) {
                          return Stack(
                            children: [
                              Container(
                                width: 85,
                                height: 85,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Image.file(_galleryFiles[idx], fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 14,
                                child: GestureDetector(
                                  onTap: () => setState(() => _galleryFiles.removeAt(idx)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // 3. Pricing
                // -------------------------------------------------------------
                _buildSectionTitle('3. Pricing', Icons.currency_rupee_rounded),
                const SizedBox(height: 10),
                _buildCard([
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(
                            label: 'Current Price (₹)',
                            hint: 'e.g. 499',
                            icon: Icons.sell_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _oldPriceController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            label: 'Old Price (Optional)',
                            hint: 'e.g. 699',
                            icon: Icons.money_off_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // 4. Service Area Configuration
                // -------------------------------------------------------------
                _buildSectionTitle('4. Service Area Configuration', Icons.map_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter service address' : null,
                    decoration: _inputDecoration(
                      label: 'Service Address',
                      hint: 'Full address of workshop or servicing location',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(
                            label: 'Latitude',
                            hint: 'e.g. 26.1445',
                            icon: Icons.explore_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(
                            label: 'Longitude',
                            hint: 'e.g. 91.7718',
                            icon: Icons.explore_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(
                            label: 'Service Radius (KM)',
                            hint: 'e.g. 20',
                            icon: Icons.radar_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isDetectingLocation ? null : _detectLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, size: 16),
                        label: const Text('Detect GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // 5. What's Included & What's Not Included
                // -------------------------------------------------------------
                _buildSectionTitle('5. What\'s Included & Not Included', Icons.checklist_rounded),
                const SizedBox(height: 10),
                _buildCard([
                  // What's Included Section
                  const Text('What\'s Included in this Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _includedItemController,
                          onSubmitted: (_) => _addIncludedItem(),
                          decoration: _inputDecoration(label: 'Add Feature / Task', hint: 'e.g. Engine flush & oil change', icon: Icons.check_circle_outline_rounded),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addIncludedItem,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_whatsIncluded.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _whatsIncluded.map((item) {
                        return Chip(
                          backgroundColor: const Color(0xFFECFDF5),
                          side: BorderSide(color: Colors.green.shade200),
                          label: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF065F46)),
                          onDeleted: () => setState(() => _whatsIncluded.remove(item)),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // What's Not Included Section
                  const Text('What\'s NOT Included (Exclusions)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notIncludedItemController,
                          onSubmitted: (_) => _addNotIncludedItem(),
                          decoration: _inputDecoration(label: 'Add Exclusion', hint: 'e.g. Spare parts cost not included', icon: Icons.cancel_outlined),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addNotIncludedItem,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  if (_whatsNotIncluded.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _whatsNotIncluded.map((item) {
                        return Chip(
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: BorderSide(color: Colors.red.shade200),
                          label: Text(item, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w600)),
                          deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF991B1B)),
                          onDeleted: () => setState(() => _whatsNotIncluded.remove(item)),
                        );
                      }).toList(),
                    ),
                  ],
                ]),
                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                              SizedBox(width: 12),
                              Text('Uploading & Submitting...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text(
                            'Submit Service For Approval',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
