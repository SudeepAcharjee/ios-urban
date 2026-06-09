import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/custom_toast.dart';
import 'complete_profile_screen.dart';
import 'location_request_screen.dart';
import 'notification_request_screen.dart';
import '../../home/views/main_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../worker/views/worker_main_screen.dart';


import 'dart:ui';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final bool isRegistration;
  const OtpScreen({super.key, required this.email, this.isRegistration = false});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController(text: '\u200B'));
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  int _currentStep = 0; // 0: Confirm, 1: Enter OTP, 2: Success
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _sendOtp() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authViewModelProvider.notifier).sendOTP(widget.email);
      if (mounted) {
        CustomToast.success(context, 'OTP sent to ${widget.email}');
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, e.toString());
        setState(() => _isLoading = false);
      }
    }
  }

  void _verifyOtp() async {
    if (_isLoading) return;

    String otp = _controllers.map((e) => e.text.replaceAll('\u200B', '')).join();
    if (otp.length < 4) {
      CustomToast.error(context, 'Please enter the 4-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await ref.read(authViewModelProvider.notifier).verifyOTP(widget.email, otp);
      
      if (mounted) {
        if (success) {
          if (widget.isRegistration) {
            setState(() {
              _isLoading = false;
              _currentStep = 2;
            });
          } else {
            CustomToast.success(context, 'OTP Verified Successfully!');
            _handleNavigation();
          }
        } else {
          setState(() => _isLoading = false);
          CustomToast.error(context, 'Invalid OTP. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomToast.error(context, e.toString());
      }
    }
  }

  void _handleOtpChange(String value, int index) {
    // 1. Handle Paste of a 4-digit code (stripping out zero-width spaces and non-digits)
    final cleanValue = value.replaceAll('\u200B', '').replaceAll(RegExp(r'\D'), '').trim();
    if (cleanValue.length == 4) {
      for (int i = 0; i < 4; i++) {
        _controllers[i].text = '\u200B${cleanValue[i]}';
        _controllers[i].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[i].text.length),
        );
      }
      _focusNodes[3].requestFocus();
      return;
    }

    // 2. Handle Backspace on an empty field (value becomes empty)
    if (value.isEmpty) {
      _controllers[index].text = '\u200B';
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[index].text.length),
      );
      if (index > 0) {
        _controllers[index - 1].text = '\u200B';
        _controllers[index - 1].selection = TextSelection.fromPosition(
          TextPosition(offset: _controllers[index - 1].text.length),
        );
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    // 3. Handle deletion of character (value becomes just the zero-width space)
    if (value == '\u200B') {
      return;
    }

    // 4. Handle typing a character (value has '\u200B' + typed character)
    final digit = value.replaceAll('\u200B', '');
    if (digit.isNotEmpty) {
      // Keep only the last character entered
      final lastDigit = digit.characters.last;
      _controllers[index].text = '\u200B$lastDigit';
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[index].text.length),
      );
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      }
    }
  }

  void _handleNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Check workers collection first
      var doc = await FirebaseFirestore.instance.collection('workers').doc(user.uid).get();
      bool isWorker = doc.exists;
      
      if (!isWorker) {
        doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      }

      final data = doc.data();

      Widget targetScreen;
      if (data == null) {
        targetScreen = const CompleteProfileScreen();
      } else if (isWorker || data['role']?.toString().toLowerCase() == 'worker') {
        targetScreen = const WorkerMainScreen();
      } else {

        final bool hasProfile = data['gender'] != null;
        final bool hasLocation = data['location'] != null || data['latitude'] != null;
        final bool hasNotifications = data['notificationsEnabled'] != null;

        if (!hasProfile) {
          targetScreen = const CompleteProfileScreen();
        } else if (!hasLocation) {
          targetScreen = const LocationRequestScreen();
        } else if (!hasNotifications) {
          targetScreen = const NotificationRequestScreen();
        } else {
          targetScreen = const MainScreen();
        }
      }


      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    final double hScale = screenHeight / 812.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.2),
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                padding: EdgeInsets.all(screenWidth * 0.08),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Material( // Added Material to fix text styling in transparent route
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentStep == 0) _buildConfirmStep(primaryColor, hScale, screenHeight),
                      if (_currentStep == 1) _buildOtpStep(primaryColor, hScale, screenHeight, screenWidth),
                      if (_currentStep == 2) _buildSuccessStep(primaryColor, hScale, screenHeight),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmStep(Color primaryColor, double hScale, double screenHeight) {
    return Column(
      children: [
        Text(
          'Verify Your Email Address',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18 * hScale.clamp(0.9, 1.1),
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          widget.email,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18 * hScale.clamp(0.9, 1.1),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Text(
          'We will send the authentication code\nto your email you entered.\nDo you want continue?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14 * hScale.clamp(0.9, 1.1),
            color: Colors.grey.shade500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.04),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: primaryColor.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Cancel', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton(
                onPressed: _sendOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpStep(Color primaryColor, double hScale, double screenHeight, double screenWidth) {
    return Column(
      children: [
        Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 24 * hScale.clamp(0.9, 1.1),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Text(
          'A verification codes has been\nsent to ${widget.email}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14 * hScale.clamp(0.9, 1.1),
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.04),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return SizedBox(
              width: (screenWidth * 0.14).clamp(45, 60),
              height: (screenWidth * 0.14).clamp(45, 60),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                autofocus: index == 0,
                style: TextStyle(fontSize: 22 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                onTap: () {
                  _controllers[index].selection = TextSelection.fromPosition(
                    TextPosition(offset: _controllers[index].text.length),
                  );
                },
                onChanged: (value) => _handleOtpChange(value, index),
              ),
            );
          }),
        ),
        SizedBox(height: screenHeight * 0.04),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading 
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Didn't receive the code? ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            GestureDetector(
              onTap: _isLoading ? null : _sendOtp,
              child: Text('Resend', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessStep(Color primaryColor, double hScale, double screenHeight) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 60 * hScale.clamp(0.9, 1.1), color: primaryColor),
        ),
        SizedBox(height: screenHeight * 0.03),
        Text(
          'Account Created\nSuccessfully',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24 * hScale.clamp(0.9, 1.1),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2C3E50),
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Text(
          'Your account created successfully.\nEnjoy premium car wash services!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14 * hScale.clamp(0.9, 1.1),
            color: Colors.grey.shade500,
            height: 1.4,
          ),
        ),
        SizedBox(height: screenHeight * 0.04),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _handleNavigation,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
