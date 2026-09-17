import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/custom_toast.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../../core/services/cloudinary_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  String? _selectedGender;
  String? _profilePicUrl;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
    
    // Initialize with current data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userData = ref.read(userDataProvider).value;
      if (userData != null) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _locationController.text = userData['location'] ?? '';
          _selectedGender = userData['gender'];
          _profilePicUrl = userData['profilePic'];
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? finalProfilePicUrl = _profilePicUrl;

        // Upload image if a new one is selected
        if (_imageFile != null) {
          final uploadedUrl = await CloudinaryService.uploadImage(_imageFile!);
          if (uploadedUrl != null) {
            finalProfilePicUrl = uploadedUrl;
          } else {
            throw Exception('Failed to upload image to Cloudinary');
          }
        }

        final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(user.uid).get();
        final String collectionName = workerDoc.exists ? 'workers' : 'users';

        await FirebaseFirestore.instance.collection(collectionName).doc(user.uid).update({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
          'gender': _selectedGender,
          'profilePic': finalProfilePicUrl,
        });
        
        // Refresh user data provider
        ref.invalidate(userDataProvider);
        
        if (mounted) {
          CustomToast.success(context, 'Profile Updated Successfully!');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to update profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const backgroundColor = Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF111827)),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _updateProfile,
              child: const Text('Save', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                        image: _profilePicUrl != null || _imageFile != null
                          ? DecorationImage(
                              image: _imageFile != null 
                                ? FileImage(_imageFile!) as ImageProvider
                                : NetworkImage(_profilePicUrl!), 
                              fit: BoxFit.cover
                            )
                          : null,
                      ),
                      child: (_profilePicUrl == null && _imageFile == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              _buildFieldLabel('Full Name'),
              _buildTextField(_nameController, 'Enter your name', Icons.person_outline),
              const SizedBox(height: 24),

              _buildFieldLabel('Email Address'),
              _buildTextField(_emailController, 'Enter your email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 24),

              _buildFieldLabel('Phone Number'),
              _buildTextField(_phoneController, 'Enter your phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 24),

              _buildFieldLabel('Location'),
              _buildTextField(_locationController, 'Enter your location', Icons.location_on_outlined),
              const SizedBox(height: 24),

              _buildFieldLabel('Gender'),
              Row(
                children: [
                  _buildGenderChip('Male', Icons.male),
                  const SizedBox(width: 12),
                  _buildGenderChip('Female', Icons.female),
                  const SizedBox(width: 12),
                  _buildGenderChip('Other', Icons.transgender),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (val) => val == null || val.isEmpty ? 'This field is required' : null,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2029C5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  Widget _buildGenderChip(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    const primaryColor = Color(0xFF2029C5);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
