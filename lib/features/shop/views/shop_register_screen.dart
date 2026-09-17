import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/custom_toast.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/otp_screen.dart';
import '../../auth/views/widgets/role_tab_bar.dart';
import 'shop_terms_and_conditions_screen.dart';
import 'shop_privacy_policy_screen.dart';

class ShopRegisterScreen extends ConsumerStatefulWidget {
  const ShopRegisterScreen({super.key});

  @override
  ConsumerState<ShopRegisterScreen> createState() => _ShopRegisterScreenState();
}

class _ShopRegisterScreenState extends ConsumerState<ShopRegisterScreen> {
  static const primaryColor = Color(0xFF2029C5);
  static const accentEmerald = Color(0xFF10B981);

  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = true;
  String _selectedServiceType = 'Car & Bike Servicing';

  // Phone Verification States
  bool _isPhoneVerified = false;
  bool _isSendingPhoneOtp = false;
  String? _verifiedPhoneNumber;

  final List<Map<String, dynamic>> _categoryOptions = [
    {
      'title': 'Car Servicing',
      'subtitle': '4-Wheelers & SUVs',
      'icon': Icons.directions_car_filled_rounded,
    },
    {
      'title': 'Bike Servicing',
      'subtitle': '2-Wheelers & Scooters',
      'icon': Icons.two_wheeler_rounded,
    },
    {
      'title': 'Car & Bike Servicing',
      'subtitle': 'All Multi-brand Vehicles',
      'icon': Icons.car_repair_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final currentPhone = _phoneController.text.trim();
    if (_isPhoneVerified && currentPhone != _verifiedPhoneNumber) {
      setState(() {
        _isPhoneVerified = false;
        _verifiedPhoneNumber = null;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _ownerNameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startPhoneVerification() {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      CustomToast.error(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isSendingPhoneOtp = true);

    ref.read(authViewModelProvider.notifier).verifyPhoneNumber(
      phoneNumber: '+91$phone',
      onVerificationCompleted: () {
        if (mounted) {
          setState(() {
            _isSendingPhoneOtp = false;
            _isPhoneVerified = true;
            _verifiedPhoneNumber = phone;
          });
          Navigator.of(context, rootNavigator: true).maybePop();
          CustomToast.success(context, 'Phone number automatically verified!');
        }
      },
      onVerificationFailed: (error) {
        if (mounted) {
          setState(() => _isSendingPhoneOtp = false);
          CustomToast.error(context, error);
        }
      },
      onCodeSent: (verificationId) {
        if (mounted) {
          setState(() => _isSendingPhoneOtp = false);
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
      builder: (modalContext) => _ShopPhoneOtpBottomSheet(
        phoneNumber: fullPhone,
        onResendOtp: () {
          _startPhoneVerification();
        },
        onVerifyOtp: (smsCode) async {
          await ref.read(authViewModelProvider.notifier).verifySentCode(smsCode);
          if (!mounted) return;
          setState(() {
            _isPhoneVerified = true;
            _verifiedPhoneNumber = _phoneController.text.trim();
          });
          if (modalContext.mounted) {
            Navigator.of(modalContext).pop();
          }
          if (mounted) {
            CustomToast.success(context, 'Phone number verified successfully!');
          }
        },
      ),
    );
  }

  void _submitRegistration() {
    final ownerName = _ownerNameController.text.trim();
    final shopName = _shopNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (ownerName.isEmpty) {
      CustomToast.error(context, 'Please enter owner name');
      return;
    }
    if (shopName.isEmpty) {
      CustomToast.error(context, 'Please enter workshop / garage name');
      return;
    }
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      CustomToast.error(context, 'Please enter a valid email address');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      CustomToast.error(context, 'Please enter a valid 10-digit mobile number');
      return;
    }
    if (!_isPhoneVerified || _verifiedPhoneNumber != phone) {
      CustomToast.error(context, 'Please verify your mobile number with OTP first');
      _startPhoneVerification();
      return;
    }
    if (password.length < 6) {
      CustomToast.error(context, 'Password must be at least 6 characters');
      return;
    }
    if (password != confirmPassword) {
      CustomToast.error(context, 'Passwords do not match');
      return;
    }
    if (!_agreedToTerms) {
      CustomToast.error(context, 'Please accept the Partner Terms & Privacy Policy to continue');
      return;
    }

    ref.read(authViewModelProvider.notifier).registerShop(
          email: email,
          password: password,
          ownerName: ownerName,
          shopName: shopName,
          phone: '+91$phone',
          serviceType: _selectedServiceType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final double screenWidth = MediaQuery.of(context).size.width;

    ref.listen<AsyncValue<void>>(authViewModelProvider, (previous, next) {
      if (!context.mounted) return;

      if (next is AsyncError && (previous is! AsyncError || previous.error != next.error)) {
        CustomToast.error(context, next.error.toString());
      }
      if (next.hasValue && !next.isLoading && !next.hasError && (previous == null || previous.isLoading)) {
        Future.microtask(() {
          if (context.mounted) {
            CustomToast.success(context, 'Shop registered successfully! Verify OTP to continue.');
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, animation, secondaryAnimation) => OtpScreen(
                  email: _emailController.text.trim(),
                  isRegistration: true,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? (screenWidth - 500) / 2 : 20,
            vertical: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Hero
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Register Your Workshop',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Join Urban Service as a verified service partner.\nReceive customer bookings & scale your garage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 1. Workshop Category Card Selector
                _buildSectionHeader('1. Workshop Category', 'Select your primary servicing specialty'),
                const SizedBox(height: 12),
                Column(
                  children: _categoryOptions.map((cat) {
                    final title = cat['title'] as String;
                    final subtitle = cat['subtitle'] as String;
                    final icon = cat['icon'] as IconData;
                    final isSelected = _selectedServiceType == title;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedServiceType = title),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? primaryColor : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.1)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? primaryColor : const Color(0xFF64748B),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? primaryColor : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? primaryColor : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? primaryColor : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 2. Workshop & Owner Information
                _buildSectionHeader('2. Workshop & Owner Details', 'Provide authentic business details'),
                const SizedBox(height: 12),

                Container(
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
                      _buildModernTextField(
                        controller: _ownerNameController,
                        label: 'Owner Full Name',
                        hintText: 'e.g. Ramesh Kumar',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _shopNameController,
                        label: 'Workshop / Garage Name',
                        hintText: 'e.g. SpeedX Motors & Care',
                        icon: Icons.store_mall_directory_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _emailController,
                        label: 'Business Email Address',
                        hintText: 'e.g. workshop@example.com',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildPhoneField(),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Security Credentials
                _buildSectionHeader('3. Security Credentials', 'Create a password for your partner login'),
                const SizedBox(height: 12),

                Container(
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
                      _buildModernTextField(
                        controller: _passwordController,
                        label: 'Create Password',
                        hintText: 'At least 6 characters',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 16),
                      _buildModernTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Repeat password',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Terms and Conditions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _agreedToTerms,
                          activeColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          children: [
                            const Text(
                              'By continuing, you agree to our ',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ShopTermsAndConditionsScreen()),
                                );
                              },
                              child: const Text(
                                'Partner Terms & Conditions',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  decoration: TextDecoration.underline,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const Text(
                              ' and ',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ShopPrivacyPolicyScreen()),
                                );
                              },
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  decoration: TextDecoration.underline,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text(
                            'Create Partner Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Already have account
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already registered as a partner? ',
                        style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(initialRole: AuthRole.shop),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Primary Contact Mobile',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isPhoneVerified
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFE2E8F0),
              width: _isPhoneVerified ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: '10-digit mobile number',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixText: '+91 ',
                    prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontSize: 14.5,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.phone_iphone_rounded, color: Color(0xFF64748B), size: 20),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  ),
                ),
              ),

              // Verification Status Chip / Button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _isPhoneVerified
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: accentEmerald, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isSendingPhoneOtp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          )
                        : TextButton(
                            onPressed: _startPhoneVerification,
                            style: TextButton.styleFrom(
                              backgroundColor: primaryColor.withValues(alpha: 0.08),
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Verify OTP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.normal,
              ),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontSize: 14.5,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: const Color(0xFF64748B), size: 20),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShopPhoneOtpBottomSheet extends StatefulWidget {
  final String phoneNumber;
  final VoidCallback onResendOtp;
  final Future<void> Function(String smsCode) onVerifyOtp;

  const _ShopPhoneOtpBottomSheet({
    required this.phoneNumber,
    required this.onResendOtp,
    required this.onVerifyOtp,
  });

  @override
  State<_ShopPhoneOtpBottomSheet> createState() => _ShopPhoneOtpBottomSheetState();
}

class _ShopPhoneOtpBottomSheetState extends State<_ShopPhoneOtpBottomSheet> {
  static const primaryColor = Color(0xFF2029C5);
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 30);
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

  String get _currentOtp => _controllers.map((c) => c.text.trim()).join();

  void _submitCode() async {
    final otp = _currentOtp;
    if (otp.length != 6) {
      CustomToast.error(context, 'Please enter all 6 digits of the SMS code');
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
            'Verify Mobile Number',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Enter the 6-digit SMS verification code sent to\n${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
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
                    : "Didn't receive SMS code?",
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
                  borderRadius: BorderRadius.circular(16),
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
