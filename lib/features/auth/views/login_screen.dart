import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../core/providers/maintenance_provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'complete_profile_screen.dart';
import '../../home/views/main_screen.dart';
import '../../worker/views/worker_main_screen.dart';
import '../../shop/views/shop_main_screen.dart';
import '../../shop/views/shop_onboarding_screen.dart';
import '../../shop/views/shop_waiting_approval_screen.dart';
import '../../shop/views/shop_register_screen.dart';
import 'widgets/role_tab_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final AuthRole initialRole;
  const LoginScreen({super.key, this.initialRole = AuthRole.user});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late AuthRole _selectedRole;
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showBlockedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Blocked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Your account has been blocked by the administrator. Please contact support for more information.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.engineering_rounded, color: Colors.amber.shade700, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'System Maintenance',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
        content: const Text(
          'Our app is currently undergoing scheduled maintenance to improve your experience. We will be back online shortly!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2029C5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Got it!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      ),
    );
  }

  Future<void> _navigateAfterAuth(User user) async {
    try {
      final uid = user.uid;
      // Check shops collection
      final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(uid).get();
      if (shopDoc.exists) {
        final data = shopDoc.data() ?? {};
        final bool onboardingCompleted = data['onboardingCompleted'] == true;
        final String shopStatus = (data['status'] ?? 'pending').toString().toLowerCase();

        if (!onboardingCompleted) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => ShopOnboardingScreen(initialShopData: data)),
              (route) => false,
            );
          }
          return;
        } else if (shopStatus == 'active' || shopStatus == 'approved') {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ShopMainScreen()),
              (route) => false,
            );
          }
          return;
        } else {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ShopWaitingApprovalScreen()),
              (route) => false,
            );
          }
          return;
        }
      }

      // Check workers collection
      final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
      if (workerDoc.exists) {
        final data = workerDoc.data() ?? {};
        final bool hasProfile = data['name'] != null && data['phone'] != null;
        if (!hasProfile) {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
              (route) => false,
            );
          }
          return;
        } else {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WorkerMainScreen()),
              (route) => false,
            );
          }
          return;
        }
      }

      // Default: users collection
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    final isMaintenance = ref.read(maintenanceProvider).value ?? false;
    if (isMaintenance) {
      if (mounted) {
        _showMaintenanceDialog(context);
      }
      return;
    }
    try {
      await ref.read(authViewModelProvider.notifier).login(
        _mobileController.text.trim(),
        _passwordController.text,
        expectedRole: _selectedRole.name,
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && mounted) {
        await _navigateAfterAuth(currentUser);
      }
    } catch (e) {
      if (mounted) {
        final error = e.toString();
        if (error == 'USER_NOT_FOUND_IN_FIRESTORE') {
          if (_selectedRole == AuthRole.shop) {
            CustomToast.warning(context, "Shop account not found. Please register your shop first.");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ShopRegisterScreen()),
            );
          } else if (_selectedRole == AuthRole.worker) {
            CustomToast.error(context, "Worker account not found. Please contact your manager or admin.");
          } else {
            CustomToast.warning(context, "Don't have an account? Please register first.");
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const RegisterScreen()),
            );
          }
        } else if (error == 'ACCOUNT_BLOCKED') {
          _showBlockedDialog(context);
        } else {
          CustomToast.error(context, error);
        }
      }
    }
  }

  Future<void> _handleSocialLogin(Future<void> Function() loginMethod) async {
    final isMaintenance = ref.read(maintenanceProvider).value ?? false;
    if (isMaintenance) {
      if (mounted) {
        _showMaintenanceDialog(context);
      }
      return;
    }
    try {
      await loginMethod();
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && mounted) {
        await _navigateAfterAuth(firebaseUser);
      }
    } catch (e) {
      if (mounted) {
        final error = e.toString();
        if (error == 'USER_NOT_FOUND_IN_FIRESTORE') {
          CustomToast.warning(context, "Don't have an account? Please register first.");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          );
        } else if (error == 'ACCOUNT_BLOCKED') {
          _showBlockedDialog(context);
        } else {
          CustomToast.error(context, error);
        }
      }
    }
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

    String titleText = 'Welcome Back';
    String subtitleText = 'Log in to your account using\nemail address or social networks';
    if (_selectedRole == AuthRole.worker) {
      titleText = 'Worker Portal';
      subtitleText = 'Log in with your technician account\nto access assigned service tasks';
    } else if (_selectedRole == AuthRole.shop) {
      titleText = 'Shop Owner Portal';
      subtitleText = 'Log in to manage your car & bike\nservicing workshop';
    }

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
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.08,
                      vertical: screenHeight * 0.02,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 28 * hScale.clamp(0.8, 1.2),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.01),
                        
                        Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14 * hScale.clamp(0.9, 1.1),
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.035),
                        

                        
                        // Role Selector Tab Bar (User | Worker | Shop) - Below "Or continue with email account"
                        RoleTabBar(
                          selectedRole: _selectedRole,
                          onRoleChanged: (role) {
                            setState(() {
                              _selectedRole = role;
                            });
                          },
                        ),
                        
                        SizedBox(height: screenHeight * 0.025),
                        
                        // Mobile / Email Field
                        _buildInputField(
                          controller: _mobileController,
                          hintText: 'Email Address',
                          keyboardType: TextInputType.emailAddress,
                          hScale: hScale,
                        ),
                        
                        SizedBox(height: screenHeight * 0.015),
                        
                        // Password Field
                        _buildInputField(
                          controller: _passwordController,
                          hintText: 'Password',
                          obscureText: _obscurePassword,
                          hScale: hScale,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.015),
                        
                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                              );
                            },
                            child: Text(
                              'Forgot Password ?',
                              style: TextStyle(
                                color: const Color(0xFF2029C5),
                                fontSize: 14 * hScale.clamp(0.9, 1.1),
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.04),
                        
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: (screenHeight * 0.065).clamp(50, 65),
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: authState.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18 * hScale.clamp(0.9, 1.1),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.045),
                        
                        // Signup Footer
                        if (_selectedRole == AuthRole.worker)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Worker accounts are provisioned by workshop managers or administrators.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13 * hScale.clamp(0.9, 1.1),
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedRole == AuthRole.shop
                                    ? "Haven't registered your shop? "
                                    : "Didn't have an account? ",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14 * hScale.clamp(0.9, 1.1),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_selectedRole == AuthRole.shop) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ShopRegisterScreen()),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: Text(
                                  _selectedRole == AuthRole.shop ? 'Register Shop' : 'Signup',
                                  style: TextStyle(
                                    color: const Color(0xFF2029C5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 * hScale.clamp(0.9, 1.1),
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

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color contentColor,
    required double hScale,
  }) {
    return SizedBox(
      width: double.infinity,
      height: (MediaQuery.of(context).size.height * 0.065).clamp(50, 60),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: backgroundColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: contentColor,
                fontSize: 16 * hScale.clamp(0.9, 1.1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required double hScale,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16 * hScale.clamp(0.9, 1.1)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15 * hScale.clamp(0.9, 1.1),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}
