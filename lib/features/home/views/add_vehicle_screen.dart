import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/vehicle_provider.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../core/services/cloudinary_service.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  final bool showAddedVehiclesFirst;

  const AddVehicleScreen({
    super.key,
    this.showAddedVehiclesFirst = false,
  });

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  late bool _isAddingNew;
  bool _isSaving = false;
  String? _editingVehicleId;
  String? _editingImageUrl;
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isAddingNew = widget.showAddedVehiclesFirst ? false : true;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            final vehiclesAsync = ref.read(vehiclesProvider);
            final hasVehicles = vehiclesAsync.maybeWhen(
              data: (list) => list.isNotEmpty,
              orElse: () => false,
            );

            if (_isAddingNew && hasVehicles) {
              setState(() {
                _isAddingNew = false;
                _editingVehicleId = null;
                _editingImageUrl = null;
                _makeController.clear();
                _modelController.clear();
                _yearController.clear();
                _licenseController.clear();
                _imageFile = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF111827)),
          ),
        ),
        title: Text(
          _isAddingNew 
              ? (_editingVehicleId != null ? 'Edit Vehicle' : 'Add Vehicle') 
              : 'My Vehicles',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ref.watch(vehiclesProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (vehicles) {
                  // Adjust _isAddingNew if list is empty and we haven't set it yet
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _isAddingNew ? _buildAddVehicleForm() : _buildVehicleList(vehicles),
                  );
                },
              ),
            ),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () {
                    if (_isAddingNew) {
                      _saveVehicle();
                    } else {
                      setState(() => _isAddingNew = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: primaryColor.withOpacity(0.7),
                  ),
                  child: _isSaving 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isAddingNew 
                            ? (_editingVehicleId != null ? 'Update Vehicle' : 'Save Vehicle') 
                            : 'Add New Vehicle',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList(List<Map<String, dynamic>> vehicles) {
    if (vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No vehicles added yet',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Registered Vehicles',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return _buildVehicleItem(vehicle, index);
          },
        ),
      ],
    );
  }

  Widget _buildVehicleItem(Map<String, dynamic> vehicle, int index) {
    const primaryColor = Color(0xFF2029C5);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              image: (vehicle['imageUrl'] != null && vehicle['imageUrl'].isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(vehicle['imageUrl']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (vehicle['imageUrl'] == null || vehicle['imageUrl'].isEmpty)
                ? const Icon(Icons.directions_car, color: primaryColor, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehicle['year']} ${vehicle['make']} ${vehicle['model']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plate: ${vehicle['license']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _editingVehicleId = vehicle['id'];
                _editingImageUrl = vehicle['imageUrl'];
                _makeController.text = vehicle['make'] ?? '';
                _modelController.text = vehicle['model'] ?? '';
                _yearController.text = vehicle['year'] ?? '';
                _licenseController.text = vehicle['license'] ?? '';
                _imageFile = null;
                _isAddingNew = true;
              });
            },
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 22),
          ),
          IconButton(
            onPressed: () async {
              final vehicleId = vehicle['id'];
              if (vehicleId != null) {
                await VehicleService.deleteVehicle(vehicleId);
                if (mounted) {
                  CustomToast.success(context, 'Vehicle deleted successfully');
                }
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Upload Photo Box
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    )
                  : (_editingImageUrl != null && _editingImageUrl!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(_editingImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: (_imageFile == null && (_editingImageUrl == null || _editingImageUrl!.isEmpty))
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Upload Vehicle Photo',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        const SizedBox(height: 32),

        // 2. Form Fields
        _buildLabel('Make'),
        TextField(
          controller: _makeController,
          style: const TextStyle(fontWeight: FontWeight.w500),
          inputFormatters: [
            LengthLimitingTextInputFormatter(30),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. Toyota',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2029C5), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('Model'),
        TextField(
          controller: _modelController,
          style: const TextStyle(fontWeight: FontWeight.w500),
          inputFormatters: [
            LengthLimitingTextInputFormatter(30),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. Camry',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2029C5), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('Year'),
        TextField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontWeight: FontWeight.w500),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. 2022',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2029C5), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildLabel('License Plate Number'),
        TextField(
          controller: _licenseController,
          style: const TextStyle(fontWeight: FontWeight.w500),
          inputFormatters: [
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            hintText: 'e.g. ABC 1234',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF2029C5), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _saveVehicle() async {
    if (_makeController.text.isNotEmpty && 
        _modelController.text.isNotEmpty && 
        _yearController.text.isNotEmpty && 
        _licenseController.text.isNotEmpty) {
      try {
        setState(() => _isSaving = true);

        String? imageUrl = _editingImageUrl;
        if (_imageFile != null) {
          imageUrl = await CloudinaryService.uploadImage(_imageFile!, folder: 'vehicles');
        }

        final vehicleData = {
          'make': _makeController.text.trim(),
          'model': _modelController.text.trim(),
          'year': _yearController.text.trim(),
          'license': _licenseController.text.trim(),
          'imageUrl': imageUrl ?? '',
        };

        final bool isEditing = _editingVehicleId != null;
        if (isEditing) {
          await VehicleService.updateVehicle(_editingVehicleId!, vehicleData);
        } else {
          await VehicleService.addVehicle(vehicleData);
        }

        if (mounted) {
          setState(() {
            _isAddingNew = false;
            _isSaving = false;
            _editingVehicleId = null;
            _editingImageUrl = null;
            _imageFile = null;
            // Reset form
            _makeController.clear();
            _modelController.clear();
            _yearController.clear();
            _licenseController.clear();
          });
          CustomToast.success(context, isEditing ? 'Vehicle updated successfully' : 'Vehicle added successfully');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          CustomToast.error(context, 'Error saving vehicle: $e');
        }
      }
    } else {
      CustomToast.warning(context, 'Please fill all fields');
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }


}
