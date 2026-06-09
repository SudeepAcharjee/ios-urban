import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/custom_toast.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    
    // Scale factor based on standard height (812.0)
    final double hScale = screenHeight / 812.0;

    ref.listen<AsyncValue<void>>(authViewModelProvider, (previous, next) {
      if (!context.mounted) return;

      if (next is AsyncError && (previous is! AsyncError || previous.error != next.error)) {
        CustomToast.error(context, next.error.toString());
      }
      if (next.hasValue && !next.isLoading && !next.hasError && (previous == null || previous.isLoading)) {
        // If email controller is empty, it was likely a social sign-in from this screen
        if (_emailController.text.isEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.email != null) {
            Future.microtask(() {
              if (context.mounted) {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (context, _, __) => OtpScreen(email: user.email!),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                  ),
                );
              }
            });
          } else {
            CustomToast.error(context, 'Social login failed: Email not found.');
          }
        } else {
          Future.microtask(() {
            if (context.mounted) {
              CustomToast.success(context, 'Account created successfully!');
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (context, _, __) => OtpScreen(
                    email: _emailController.text,
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
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                      vertical: screenHeight * 0.02,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title
                        Text(
                          'Create New Account',
                          style: TextStyle(
                            fontSize: 28 * hScale.clamp(0.8, 1.2),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        
                        // Subtitle
                        Text(
                          'Set up your username and password.\nYou can always change it later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16 * hScale.clamp(0.9, 1.1),
                            color: Colors.grey,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.04),

                        if (!Platform.isIOS) ...[
                          _buildSocialButton(
                            icon: Image.asset(
                              'images/logo/google.png',
                              height: 22 * hScale.clamp(0.9, 1.1),
                              width: 22 * hScale.clamp(0.9, 1.1),
                            ),
                            label: 'Continue with Google',
                            onPressed: () => ref.read(authViewModelProvider.notifier).signInWithGoogle(isRegistration: true).catchError((_) {}),
                            hScale: hScale,
                          ),
                        ],
                        
                        SizedBox(height: screenHeight * 0.03),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('Or', style: TextStyle(color: Colors.grey)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                        
                        SizedBox(height: screenHeight * 0.03),

                        // Name Field
                        _buildTextField(
                          controller: _nameController,
                          hintText: 'Enter Name',
                          hScale: hScale,
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          hScale: hScale,
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Mobile Number Field
                        _buildTextField(
                          controller: _phoneController,
                          hintText: 'Mobile Number',
                          keyboardType: TextInputType.phone,
                          hScale: hScale,
                          prefix: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 18 * hScale.clamp(0.9, 1.1),
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          isPassword: true,
                          obscureText: _obscurePassword,
                          hScale: hScale,
                          onToggleVisibility: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        SizedBox(height: screenHeight * 0.02),

                        // Re-Enter Password Field
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Re-Enter Password',
                          isPassword: true,
                          obscureText: _obscureConfirmPassword,
                          hScale: hScale,
                          onToggleVisibility: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        SizedBox(height: screenHeight * 0.04),

                        // Signup Button
                        SizedBox(
                          width: double.infinity,
                          height: (screenHeight * 0.07).clamp(55, 70),
                          child: ElevatedButton(
                            onPressed: authState.isLoading
                                ? null
                                  : () {
                                    if (_passwordController.text.length < 6) {
                                      CustomToast.error(context, 'Password must be at least 6 characters');
                                      return;
                                    }
                                    if (_passwordController.text != _confirmPasswordController.text) {
                                      CustomToast.error(context, 'Passwords do not match');
                                      return;
                                    }
                                    ref.read(authViewModelProvider.notifier).register(
                                          email: _emailController.text,
                                          password: _passwordController.text,
                                          name: _nameController.text,
                                          phone: '+91${_phoneController.text.trim()}',
                                        );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: authState.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Signup',
                                    style: TextStyle(
                                      fontSize: 18 * hScale.clamp(0.9, 1.1),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.03),

                        // Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: const Color(0xFF4A4A4A),
                                fontSize: 15 * hScale.clamp(0.9, 1.1),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15 * hScale.clamp(0.9, 1.1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required double hScale,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 16 * hScale.clamp(0.9, 1.1),
          color: const Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15 * hScale.clamp(0.9, 1.1),
          ),
          prefixIcon: prefix != null ? Container(
            width: 70 * hScale.clamp(0.9, 1.1),
            padding: const EdgeInsets.only(left: 20),
            alignment: Alignment.centerLeft,
            child: prefix,
          ) : null,
          prefixIconConstraints: prefix != null ? BoxConstraints(
            minWidth: 70 * hScale.clamp(0.9, 1.1),
            minHeight: 0,
          ) : null,
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
    required double hScale,
    Color? backgroundColor,
    Color? contentColor,
  }) {
    return SizedBox(
      height: 55,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: contentColor ?? Colors.black, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}



