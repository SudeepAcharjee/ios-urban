import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';

class ShopEditServiceScreen extends ConsumerStatefulWidget {
  final String docId;
  final String collectionName; // 'services' or 'verify-service'
  final Map<String, dynamic> initialData;

  const ShopEditServiceScreen({
    super.key,
    required this.docId,
    required this.collectionName,
    required this.initialData,
  });

  @override
  ConsumerState<ShopEditServiceScreen> createState() => _ShopEditServiceScreenState();
}

class _ShopEditServiceScreenState extends ConsumerState<ShopEditServiceScreen> {
  static const primaryColor = Color(0xFF2029C5);
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _serviceTimeController;
  late TextEditingController _shortDescController;
  late TextEditingController _longDescController;
  late TextEditingController _priceController;
  late TextEditingController _oldPriceController;
  late TextEditingController _addressController;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  late TextEditingController _radiusController;

  final _includedItemController = TextEditingController();
  final _notIncludedItemController = TextEditingController();

  final List<String> _whatsIncluded = [];
  final List<String> _whatsNotIncluded = [];

  // Image State
  String? _existingCoverUrl;
  File? _newCoverImageFile;
  final List<String> _existingGalleryUrls = [];
  final List<File> _newGalleryFiles = [];
  final ImagePicker _picker = ImagePicker();

  // Category State
  List<Map<String, String>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isLoading = true;
  bool _isDetectingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    _nameController = TextEditingController(text: (data['name'] ?? '').toString());
    _serviceTimeController = TextEditingController(text: (data['serviceTime'] ?? '30–45 Minutes').toString());
    _shortDescController = TextEditingController(text: (data['shortDescription'] ?? '').toString());
    _longDescController = TextEditingController(text: (data['longDescription'] ?? '').toString());
    _priceController = TextEditingController(text: (data['price'] ?? '').toString());
    _oldPriceController = TextEditingController(text: (data['oldPrice'] ?? '').toString());
    _addressController = TextEditingController(text: (data['address'] ?? '').toString());
    _latController = TextEditingController(text: (data['latitude'] ?? '').toString());
    _lngController = TextEditingController(text: (data['longitude'] ?? '').toString());
    _radiusController = TextEditingController(text: (data['radius'] ?? '20').toString());

    _existingCoverUrl = data['image']?.toString();

    if (data['gallery'] is List) {
      _existingGalleryUrls.addAll(List<String>.from(data['gallery']));
    }

    if (data['whatsIncluded'] is List) {
      _whatsIncluded.addAll(List<String>.from(data['whatsIncluded']));
    }

    if (data['whatsNotIncluded'] is List) {
      _whatsNotIncluded.addAll(List<String>.from(data['whatsNotIncluded']));
    }

    _loadCategories();
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

  Future<void> _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').orderBy('name').get();
      _categories = snapshot.docs.map((d) {
        return {
          'id': d.id,
          'name': (d.data()['name'] ?? '').toString(),
        };
      }).where((c) => c['name']!.isNotEmpty).toList();

      final currentCatId = widget.initialData['categoryId']?.toString();
      final currentCatName = widget.initialData['category']?.toString();

      if (currentCatId != null && _categories.any((c) => c['id'] == currentCatId)) {
        _selectedCategoryId = currentCatId;
        _selectedCategoryName = _categories.firstWhere((c) => c['id'] == currentCatId)['name'];
      } else if (currentCatName != null && _categories.any((c) => c['name']!.toLowerCase() == currentCatName.toLowerCase())) {
        final match = _categories.firstWhere((c) => c['name']!.toLowerCase() == currentCatName.toLowerCase());
        _selectedCategoryId = match['id'];
        _selectedCategoryName = match['name'];
      } else if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first['id'];
        _selectedCategoryName = _categories.first['name'];
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
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
      setState(() => _newCoverImageFile = File(picked.path));
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
        _newGalleryFiles.addAll(validFiles);
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

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newCoverImageFile == null && (_existingCoverUrl == null || _existingCoverUrl!.isEmpty)) {
      CustomToast.error(context, 'Please provide a cover image for the service');
      return;
    }

    final price = _priceController.text.trim();
    if (double.tryParse(price) == null || double.parse(price) <= 0) {
      CustomToast.error(context, 'Please enter a valid price');
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      CustomToast.error(context, 'Please enter valid latitude and longitude coordinates');
      return;
    }

    final radius = int.tryParse(_radiusController.text.trim()) ?? 20;

    setState(() => _isSaving = true);

    try {
      // 1. Upload new cover image if picked
      String coverUrl = _existingCoverUrl ?? '';
      if (_newCoverImageFile != null) {
        final uploaded = await CloudinaryService.uploadImage(_newCoverImageFile!, folder: 'services');
        if (uploaded != null) coverUrl = uploaded;
      }

      // 2. Upload new gallery images if picked
      final allGalleryUrls = List<String>.from(_existingGalleryUrls);
      for (final f in _newGalleryFiles) {
        final url = await CloudinaryService.uploadImage(f, folder: 'services/gallery');
        if (url != null) allGalleryUrls.add(url);
      }

      final updatePayload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'category': _selectedCategoryName ?? 'Workshop',
        'categoryId': _selectedCategoryId ?? '',
        'price': price,
        'oldPrice': _oldPriceController.text.trim(),
        'serviceTime': _serviceTimeController.text.trim(),
        'shortDescription': _shortDescController.text.trim(),
        'longDescription': _longDescController.text.trim(),
        'image': coverUrl,
        'gallery': allGalleryUrls,
        'address': _addressController.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'radius': radius,
        'whatsIncluded': _whatsIncluded,
        'whatsNotIncluded': _whatsNotIncluded,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // If it was in verify-service and was rejected, reset status to Pending on edit
      if (widget.collectionName == 'verify-service') {
        final currentStatus = (widget.initialData['status'] ?? '').toString().toLowerCase();
        if (currentStatus == 'rejected') {
          updatePayload['status'] = 'Pending';
          updatePayload['rejectionReason'] = FieldValue.delete();
          updatePayload['resubmittedAt'] = FieldValue.serverTimestamp();
        }
      }

      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.docId)
          .update(updatePayload);

      if (!mounted) return;
      CustomToast.success(context, 'Service updated successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to update service: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          'Edit Service',
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
                // 1. Service Information
                _buildSectionTitle('1. Service Information', Icons.build_circle_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter service name' : null,
                    decoration: _inputDecoration(
                      label: 'Service Name',
                      hint: 'e.g. Full Synthetic Oil & Filter Service',
                      icon: Icons.title_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

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

                  TextFormField(
                    controller: _shortDescController,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter short summary' : null,
                    decoration: _inputDecoration(
                      label: 'Short Description',
                      hint: 'Brief summary displayed in service cards',
                      icon: Icons.short_text_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _longDescController,
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter full description' : null,
                    decoration: _inputDecoration(
                      label: 'Long Description',
                      hint: 'Comprehensive explanation of service coverage',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // 2. Cover Photo & Gallery
                _buildSectionTitle('2. Cover Image & Gallery', Icons.add_a_photo_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  const Text('Main Cover Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),

                  if (_newCoverImageFile != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_newCoverImageFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ] else if (_existingCoverUrl != null && _existingCoverUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(_existingCoverUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickCoverImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 15),
                          label: const Text('Change Photo (Camera)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

                  // Gallery Photos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gallery Photos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      TextButton.icon(
                        onPressed: _pickGalleryImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                        label: const Text('Add More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  if (_existingGalleryUrls.isNotEmpty || _newGalleryFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 85,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ..._existingGalleryUrls.map((url) {
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
                                    child: Image.network(url, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 14,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _existingGalleryUrls.remove(url)),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          ..._newGalleryFiles.map((file) {
                            return Stack(
                              children: [
                                Container(
                                  width: 85,
                                  height: 85,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.blue.shade300),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.file(file, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 14,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _newGalleryFiles.remove(file)),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 20),

                // 3. Pricing
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
                          decoration: _inputDecoration(label: 'Current Price (₹)', hint: 'e.g. 499', icon: Icons.sell_outlined),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _oldPriceController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(label: 'Old Price (Optional)', hint: 'e.g. 699', icon: Icons.money_off_rounded),
                        ),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 20),

                // 4. Area & Coverage
                _buildSectionTitle('4. Service Area & Radius', Icons.map_outlined),
                const SizedBox(height: 10),
                _buildCard([
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter service address' : null,
                    decoration: _inputDecoration(label: 'Service Address', hint: 'Workshop address', icon: Icons.location_on_outlined),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(label: 'Latitude', hint: 'e.g. 26.1445', icon: Icons.explore_outlined),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          decoration: _inputDecoration(label: 'Longitude', hint: 'e.g. 91.7718', icon: Icons.explore_outlined),
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
                          decoration: _inputDecoration(label: 'Service Radius (KM)', hint: 'e.g. 20', icon: Icons.radar_rounded),
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

                // 5. What's Included & Not Included
                _buildSectionTitle('5. What\'s Included & Not Included', Icons.checklist_rounded),
                const SizedBox(height: 10),
                _buildCard([
                  const Text('What\'s Included', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _includedItemController,
                          onSubmitted: (_) => _addIncludedItem(),
                          decoration: _inputDecoration(label: 'Add Feature', hint: 'e.g. Brake pad cleaning', icon: Icons.check_circle_outline_rounded),
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

                  const Text('What\'s NOT Included (Exclusions)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notIncludedItemController,
                          onSubmitted: (_) => _addNotIncludedItem(),
                          decoration: _inputDecoration(label: 'Add Exclusion', hint: 'e.g. Major engine overhaul parts', icon: Icons.cancel_outlined),
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

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveService,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                              SizedBox(width: 12),
                              Text('Saving Changes...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text('Save Service Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
