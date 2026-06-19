import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _otpController = TextEditingController();
  String? _selectedGender;
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isUploading = false;
  String? _socialImageUrl;

  bool _isPhoneVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String? _verificationId;
  String? _verifiedNumber;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      CustomToast.error(context, 'Please enter a valid 10-digit phone number');
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final formattedPhone = '+91$phone';
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution or instant verification
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
            }
            setState(() {
              _isPhoneVerified = true;
              _otpSent = false;
              _verifiedNumber = phone;
              _isSendingOtp = false;
            });
            CustomToast.success(context, 'Phone number verified automatically!');
          } catch (e) {
            // Already linked or error linking
            setState(() {
              _isPhoneVerified = true;
              _otpSent = false;
              _verifiedNumber = phone;
              _isSendingOtp = false;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isSendingOtp = false;
          });
          CustomToast.error(context, e.message ?? 'Verification failed. Please try again.');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isSendingOtp = false;
          });
          CustomToast.success(context, 'OTP sent successfully!');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isSendingOtp = false;
      });
      CustomToast.error(context, 'Error sending OTP: $e');
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      CustomToast.error(context, 'Please enter a 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            // Already linked, we can proceed
          } else if (e.code == 'credential-already-in-use') {
            // If already associated with another account, sign in or let user know
            // For profile completion page, we'll continue since the credentials are valid
          } else {
            rethrow;
          }
        }
      }

      setState(() {
        _isPhoneVerified = true;
        _otpSent = false;
        _verifiedNumber = _phoneController.text.trim();
        _isVerifyingOtp = false;
      });
      CustomToast.success(context, 'Phone number verified successfully!');
    } catch (e) {
      setState(() {
        _isVerifyingOtp = false;
      });
      CustomToast.error(context, 'Invalid OTP. Please check and try again.');
    }
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.trim();
    if (text != _verifiedNumber) {
      if (mounted) {
        setState(() {
          _isPhoneVerified = false;
          _otpSent = false;
        });
      }
    } else if (_verifiedNumber != null && text == _verifiedNumber) {
      if (mounted) {
        setState(() {
          _isPhoneVerified = true;
          _otpSent = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
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

                  if (!_isPhoneVerified) {
                    CustomToast.error(context, 'Please verify your phone number first');
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
    const primaryColor = Color(0xFF2029C5);
    final isPhoneValid = _phoneController.text.trim().length == 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: _isPhoneVerified
                ? Border.all(color: Colors.green.withOpacity(0.3))
                : null,
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
                  readOnly: _isPhoneVerified,
                  scrollPadding: EdgeInsets.only(bottom: 140 * hScale.clamp(0.8, 1.2)),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 16 * hScale.clamp(0.9, 1.1),
                    color: _isPhoneVerified ? Colors.grey.shade600 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Phone Number',
                    counterText: '',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16 * hScale.clamp(0.9, 1.1)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10 * hScale.clamp(0.8, 1.2), vertical: 15 * hScale.clamp(0.8, 1.2)),
                  ),
                ),
              ),
              if (_isPhoneVerified)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * hScale.clamp(0.8, 1.2)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_isSendingOtp)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * hScale.clamp(0.8, 1.2)),
                  child: const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  ),
                )
              else if (isPhoneValid)
                TextButton(
                  onPressed: _sendOtp,
                  child: Text(
                    _otpSent ? 'Resend' : 'Verify',
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_otpSent && !_isPhoneVerified)
          _buildOtpField(hScale),
      ],
    );
  }

  Widget _buildOtpField(double hScale) {
    const primaryColor = Color(0xFF2029C5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(top: 15.0 * hScale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Verification Code', hScale),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: TextStyle(fontSize: 16 * hScale.clamp(0.9, 1.1), letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: 'Enter 6-digit OTP',
                      counterText: '',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400, 
                        fontSize: 15 * hScale.clamp(0.9, 1.1),
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20 * hScale.clamp(0.8, 1.2), 
                        vertical: 15 * hScale.clamp(0.8, 1.2)
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10 * hScale.clamp(0.8, 1.2)),
                  child: _isVerifyingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _verifyOtp,
                          child: const Text(
                            'Verify OTP',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
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
