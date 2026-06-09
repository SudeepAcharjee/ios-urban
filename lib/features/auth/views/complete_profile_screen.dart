import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/custom_toast.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'location_request_screen.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGender;
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isUploading = false;
  String? _socialImageUrl;

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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double hScale = size.height / 812.0;
    
    // Listen to userData for auto-filling instead of doing it in build
    ref.listen<AsyncValue<Map<String, dynamic>?>>(userDataProvider, (previous, next) {
      next.whenData((data) {
        if (data != null) {
          if (_nameController.text.isEmpty && data['name'] != null) {
            _nameController.text = data['name'];
          }
          if (_emailController.text.isEmpty && data['email'] != null) {
            _emailController.text = data['email'];
          }
          if (_phoneController.text.isEmpty && data['phone'] != null) {
            String phone = data['phone'];
            if (phone.startsWith('+91')) {
              phone = phone.substring(3);
            }
            _phoneController.text = phone;
            // If phone exists in DB, we consider it verified for this session
          }
          if (_socialImageUrl == null && data['profilePic'] != null && data['profilePic'].toString().isNotEmpty) {
            _socialImageUrl = data['profilePic'];
          }
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(
              left: 25.0 * hScale.clamp(0.8, 1.2),
              right: 25.0 * hScale.clamp(0.8, 1.2),
              bottom: 60.0 * hScale,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              SizedBox(height: 10 * hScale),
            Center(
              child: Text(
                'Complete Your Profile',
                style: TextStyle(
                  fontSize: 26 * hScale.clamp(0.9, 1.1),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            SizedBox(height: 10 * hScale),
            Center(
              child: Text(
                "Don't worry, only you can see your personal\ndata. No one else will be able to see it.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14 * hScale.clamp(0.9, 1.1),
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: 40 * hScale),
            
            // Profile Picture
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 110 * hScale.clamp(0.8, 1.2),
                      height: 110 * hScale.clamp(0.8, 1.2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : (_socialImageUrl != null && _socialImageUrl!.isNotEmpty)
                                ? DecorationImage(
                                    image: NetworkImage(_socialImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (_imageFile == null && (_socialImageUrl == null || _socialImageUrl!.isEmpty))
                          ? Icon(Icons.person, size: 60 * hScale.clamp(0.8, 1.2), color: primaryColor)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(6 * hScale.clamp(0.8, 1.2)),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.edit, size: 14 * hScale.clamp(0.8, 1.2), color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 40 * hScale),
            
            _buildLabel('Name', hScale),
            _buildTextField(
              controller: _nameController,
              hintText: 'Ex. John Doe',
              hScale: hScale,
            ),
            
            SizedBox(height: 20 * hScale),

            _buildLabel('Email', hScale),
            _buildTextField(
              controller: _emailController,
              hintText: 'email@example.com',
              hScale: hScale,
              readOnly: true,
              prefixIcon: Icons.email_outlined,
            ),
            
            SizedBox(height: 20 * hScale),
            
            _buildLabel('Phone Number', hScale),
            _buildPhoneField(hScale),
            
            SizedBox(height: 20 * hScale),
            
            _buildLabel('Gender', hScale),
            _buildGenderDropdown(hScale, primaryColor),
            
            SizedBox(height: 40 * hScale),
            
            SizedBox(
              width: double.infinity,
              height: (55 * hScale).clamp(55, 70),
              child: ElevatedButton(
                onPressed: (_isUploading || ref.watch(authViewModelProvider).isLoading) ? null : () async {
                  FocusScope.of(context).unfocus();
                  if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _selectedGender == null) {
                    CustomToast.error(context, 'Please fill all fields');
                    return;
                  }

                  try {
                    setState(() => _isUploading = true);
                    
                    String? imageUrl;
                    if (_imageFile != null) {
                      imageUrl = await CloudinaryService.uploadImage(_imageFile!);
                      if (imageUrl == null) {
                        if (mounted) {
                          CustomToast.error(context, 'Image upload failed');
                          setState(() => _isUploading = false);
                        }
                        return;
                      }
                    }

                    await ref.read(authViewModelProvider.notifier).updateProfile({
                      'name': _nameController.text.trim(),
                      'phone': '+91${_phoneController.text.trim()}',
                      'gender': _selectedGender,
                      if (imageUrl != null) 'profilePic': imageUrl,
                    });
                    
                    if (mounted) {
                      setState(() => _isUploading = false);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LocationRequestScreen()),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isUploading = false);
                      CustomToast.error(context, e.toString());
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: primaryColor.withOpacity(0.7),
                ),
                child: (_isUploading || ref.watch(authViewModelProvider).isLoading)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20 * hScale.clamp(0.8, 1.2),
                            width: 20 * hScale.clamp(0.8, 1.2),
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12 * hScale),
                          Text(
                            'Updating Profile...',
                            style: TextStyle(fontSize: 18 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Text(
                        'Complete Profile',
                        style: TextStyle(fontSize: 18 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            SizedBox(height: 30 * hScale),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildLabel(String text, double hScale) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0 * hScale, left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16 * hScale.clamp(0.9, 1.1),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String hintText, 
    required double hScale,
    bool readOnly = false,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: readOnly ? Border.all(color: Colors.grey.shade200) : null,
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        scrollPadding: EdgeInsets.only(bottom: 140 * hScale.clamp(0.8, 1.2)),
        style: TextStyle(
          fontSize: 16 * hScale.clamp(0.9, 1.1),
          color: readOnly ? Colors.grey.shade600 : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey, size: 20 * hScale) : null,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16 * hScale.clamp(0.9, 1.1)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20 * hScale.clamp(0.8, 1.2), 
            vertical: 15 * hScale.clamp(0.8, 1.2)
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(double hScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12 * hScale.clamp(0.8, 1.2)),
                child: Row(
                  children: [
                    Text('+91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * hScale.clamp(0.9, 1.1))),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 20 * hScale.clamp(0.8, 1.2)),
                    SizedBox(width: 8 * hScale),
                    Container(height: 20 * hScale, width: 1, color: Colors.grey.shade300),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  scrollPadding: EdgeInsets.only(bottom: 140 * hScale.clamp(0.8, 1.2)),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(fontSize: 16 * hScale.clamp(0.9, 1.1)),
                  decoration: InputDecoration(
                    hintText: 'Enter Phone Number',
                    counterText: '',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16 * hScale.clamp(0.9, 1.1)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10 * hScale.clamp(0.8, 1.2), vertical: 15 * hScale.clamp(0.8, 1.2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(double hScale, Color primaryColor) {
    return _buildDropdown(
      context: context,
      value: _selectedGender,
      hint: 'Select Gender',
      items: ['Male', 'Female', 'Other'],
      hScale: hScale,
      primaryColor: primaryColor,
      onChanged: (newValue) {
        setState(() {
          _selectedGender = newValue;
        });
      },
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String? value,
    required String hint,
    required List<String> items,
    required double hScale,
    required Color primaryColor,
    required ValueChanged<String?> onChanged,
  }) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          backgroundColor: Colors.white,
          builder: (context) {
            return Container(
              padding: EdgeInsets.fromLTRB(24 * hScale.clamp(0.8, 1.2), 24 * hScale.clamp(0.8, 1.2), 24 * hScale.clamp(0.8, 1.2), 30 * hScale.clamp(0.8, 1.2)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hint,
                    style: TextStyle(fontSize: 18 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                  ),
                  SizedBox(height: 15 * hScale),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = value == item;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item,
                            style: TextStyle(
                              fontSize: 16 * hScale.clamp(0.9, 1.1),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? primaryColor : const Color(0xFF334155),
                            ),
                          ),
                          trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor, size: 24 * hScale.clamp(0.8, 1.2)) : null,
                          onTap: () {
                            onChanged(item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 15 * hScale.clamp(0.8, 1.2), horizontal: 4 * hScale.clamp(0.8, 1.2)),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: Row(
          children: [
            Text(
              value ?? hint,
              style: TextStyle(
                fontSize: 15 * hScale.clamp(0.9, 1.1),
                fontWeight: FontWeight.w500,
                color: value != null ? const Color(0xFF1E293B) : Colors.grey.shade400,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, color: const Color(0xFF64748B), size: 24 * hScale.clamp(0.8, 1.2)),
          ],
        ),
      ),
    );
  }
}
