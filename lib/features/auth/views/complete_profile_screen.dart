import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/constants/auth_constants.dart';
import '../../../core/utils/custom_toast.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'location_request_screen.dart';
import '../../worker/views/worker_main_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  bool _isPhoneVerified = false;
  String? _verifiedPhoneNumber;
  bool _isSendingOtp = false;

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
            _buildPhoneField(hScale, primaryColor),
            
            SizedBox(height: 20 * hScale),
            
            _buildLabel('Gender', hScale),
            _buildGenderDropdown(hScale, primaryColor),
            
            SizedBox(height: 40 * hScale),
            
            SizedBox(
              width: double.infinity,
              height: (55 * hScale).clamp(55, 70),
              child: ElevatedButton(
                onPressed: (_isUploading || _isSendingOtp || ref.watch(authViewModelProvider).isLoading) ? null : () async {
                  FocusScope.of(context).unfocus();
                  if (_nameController.text.trim().isEmpty) {
                    CustomToast.error(context, 'Please enter your name');
                    return;
                  }
                  if (_phoneController.text.trim().length != 10) {
                    CustomToast.error(context, 'Please enter a valid 10-digit phone number');
                    return;
                  }

                  final userRole = ref.read(userDataProvider).value?['role']?.toString().toLowerCase();
                  final isWorker = userRole == 'worker';
                  if (!isWorker && _selectedGender == null) {
                    CustomToast.error(context, 'Please select your gender');
                    return;
                  }

                  // If phone is not verified and verification is enabled, start Firebase Phone Verification flow
                  if (kRequirePhoneVerification && (!_isPhoneVerified || _phoneController.text.trim() != _verifiedPhoneNumber)) {
                    _startPhoneVerification();
                    return;
                  }

                  await _saveProfileAndNavigate();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: primaryColor.withValues(alpha: 0.7),
                ),
                child: (_isUploading || _isSendingOtp || ref.watch(authViewModelProvider).isLoading)
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

  Future<void> _saveProfileAndNavigate() async {
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

      final user = FirebaseAuth.instance.currentUser;
      bool isWorker = false;
      if (user != null) {
        final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(user.uid).get();
        isWorker = workerDoc.exists || (ref.read(userDataProvider).value?['role']?.toString().toLowerCase() == 'worker');
      }

      await ref.read(authViewModelProvider.notifier).updateProfile({
        'name': _nameController.text.trim(),
        'phone': '+91${_phoneController.text.trim()}',
        'phoneVerified': true,
        if (_selectedGender != null) 'gender': _selectedGender,
        if (imageUrl != null) 'profilePic': imageUrl,
      });

      if (mounted) {
        setState(() => _isUploading = false);
        CustomToast.success(context, 'Profile completed successfully!');
        if (isWorker) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WorkerMainScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LocationRequestScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        CustomToast.error(context, e.toString());
      }
    }
  }

  void _startPhoneVerification() {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      CustomToast.error(context, 'Please enter a valid 10-digit phone number');
      return;
    }

    setState(() => _isSendingOtp = true);

    ref.read(authViewModelProvider.notifier).verifyPhoneNumber(
      phoneNumber: '+91$phone',
      onVerificationCompleted: () {
        if (mounted) {
          setState(() {
            _isSendingOtp = false;
            _isPhoneVerified = true;
            _verifiedPhoneNumber = phone;
          });
          Navigator.of(context, rootNavigator: true).maybePop();
          CustomToast.success(context, 'Phone number automatically verified!');
          _saveProfileAndNavigate();
        }
      },
      onVerificationFailed: (error) {
        if (mounted) {
          setState(() => _isSendingOtp = false);
          CustomToast.error(context, error);
        }
      },
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() => _isSendingOtp = false);
          _showPhoneOtpModal('+91$phone');
        }
      },
    );
  }

  void _showPhoneOtpModal(String fullPhone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _PhoneOtpBottomSheet(
        phoneNumber: fullPhone,
        onResendOtp: () {
          _startPhoneVerification();
        },
        onVerifyOtp: (smsCode) async {
          await ref.read(authViewModelProvider.notifier).verifySentCode(smsCode);
          if (mounted) {
            setState(() {
              _isPhoneVerified = true;
              _verifiedPhoneNumber = _phoneController.text.trim();
            });
            Navigator.of(modalContext).pop();
            CustomToast.success(context, 'Phone number verified successfully!');
            await _saveProfileAndNavigate();
          }
        },
      ),
    );
  }

  Widget _buildPhoneField(double hScale, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: (kRequirePhoneVerification && _isPhoneVerified)
                ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.5)
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
                  onChanged: (val) {
                    if (_isPhoneVerified && val != _verifiedPhoneNumber) {
                      setState(() => _isPhoneVerified = false);
                    } else if (val.length == 10) {
                      setState(() {});
                    }
                  },
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
              if (kRequirePhoneVerification) ...[
                if (_isPhoneVerified)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_phoneController.text.length == 10)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton(
                      onPressed: _isSendingOtp ? null : _startPhoneVerification,
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      child: _isSendingOtp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                    ),
                  ),
              ],
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

class _PhoneOtpBottomSheet extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onResendOtp;
  final Future<void> Function(String smsCode) onVerifyOtp;

  const _PhoneOtpBottomSheet({
    required this.phoneNumber,
    required this.onResendOtp,
    required this.onVerifyOtp,
  });

  @override
  State<_PhoneOtpBottomSheet> createState() => _PhoneOtpBottomSheetState();
}

class _PhoneOtpBottomSheetState extends State<_PhoneOtpBottomSheet> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _submitCode() async {
    final otp = _currentOtp;
    if (otp.length != 6) {
      CustomToast.error(context, 'Please enter all 6 digits');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await widget.onVerifyOtp(otp);
    } catch (_) {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.sms_outlined, color: primaryColor, size: 28),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Verify Phone Number',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Enter the 6-digit code sent to ${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // 6-digit OTP fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 44,
                height: 52,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: EdgeInsets.zero,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty) {
                      if (index < 5) {
                        _focusNodes[index + 1].requestFocus();
                      } else {
                        _focusNodes[index].unfocus();
                        _submitCode();
                      }
                    } else if (val.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Resend Code
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _secondsRemaining > 0
                    ? 'Resend code in ${_secondsRemaining}s'
                    : "Didn't receive code?",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (_secondsRemaining == 0) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    widget.onResendOtp();
                    _startTimer();
                  },
                  child: const Text(
                    'Resend',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _submitCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
