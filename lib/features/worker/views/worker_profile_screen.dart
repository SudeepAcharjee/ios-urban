import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import '../../home/views/edit_profile_screen.dart';
import '../../home/views/my_reviews_screen.dart';
import 'worker_kyc_screen.dart';
import 'worker_tasks_screen.dart';
import 'worker_payment_details.dart';
import 'worker_disabled_overlay.dart';
import '../../../core/providers/app_info_provider.dart';

class WorkerProfileScreen extends ConsumerWidget {
  const WorkerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final appVersionAsync = ref.watch(appVersionProvider);
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    
    // Scale factor based on standard height (812.0)
    final double hScale = screenHeight / 812.0;

    // Define profile items configuration
    final profileItems = [
      _ProfileItemConfig(
        icon: Icons.person_outline_rounded,
        title: 'Edit Profile',
        subtitle: 'Update your personal information',
        iconColor: const Color(0xFF3B82F6), // Blue
        bgColor: const Color(0xFFEFF6FF), // Light Blue
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.verified_user_outlined,
        title: 'Uploaded KYC',
        subtitle: 'Manage your professional documents',
        iconColor: const Color(0xFF10B981), // Green
        bgColor: const Color(0xFFECFDF5), // Light Green
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerKycScreen(showAppBar: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.assignment_outlined,
        title: 'My Tasks',
        subtitle: 'View your task history and assignments',
        iconColor: const Color(0xFF8B5CF6), // Purple
        bgColor: const Color(0xFFF5F3FF), // Light Purple
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerTasksScreen(showAppBar: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.star_outline_rounded,
        title: 'My Reviews',
        subtitle: 'See your customer reviews & ratings',
        iconColor: const Color(0xFFF59E0B), // Amber
        bgColor: const Color(0xFFFEF3C7), // Light Amber
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyReviewsScreen(isWorker: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payment Info',
        subtitle: 'View your earnings and settlements',
        iconColor: const Color(0xFF3B82F6), // Blue
        bgColor: const Color(0xFFEFF6FF), // Light Blue
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkerPaymentDetailsScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.logout_outlined,
        title: 'Logout',
        subtitle: 'Sign out of your account',
        iconColor: const Color(0xFFEF4444), // Red
        bgColor: const Color(0xFFFEF2F2), // Light Red
        isDestructive: true,
        onTap: () => _showLogoutDialog(context, ref),
      ),
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8FAFC), // Modern off-white background
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8FAFC),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: const Text(
              'My Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          body: userDataAsync.when(
            data: (userData) {
              final name = userData?['name'] ?? userData?['fullName'] ?? 'Worker Name';
              final profilePic = userData?['profilePic'];

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: screenWidth * 0.05,
                  right: screenWidth * 0.05,
                  top: screenHeight * 0.01,
                  bottom: screenHeight * 0.04,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Profile Header Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF3B82F6), // Main vibrant blue
                            Color(0xFF4F46E5), // Premium Indigo
                          ],
                          begin: Alignment.bottomRight,
                          end: Alignment.topLeft,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            // Concentric circles styling on the right side
                            Positioned(
                              right: -60,
                              top: -20,
                              bottom: -20,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -100,
                              top: -60,
                              bottom: -60,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.06),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -140,
                              top: -100,
                              bottom: -100,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.04),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Card content
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 28,
                              ),
                              child: Row(
                                children: [
                                  // White avatar container
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: profilePic != null && profilePic.toString().isNotEmpty
                                          ? Image.network(
                                              profilePic,
                                              fit: BoxFit.cover,
                                              width: 80,
                                              height: 80,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.person_rounded,
                                                size: 44,
                                                color: Color(0xFF3B82F6),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              size: 44,
                                              color: Color(0xFF3B82F6),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Name & View button
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const EditProfileScreen(),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'View & manage your account',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    // Bottom Profile Items Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Column(
                          children: [
                            for (int i = 0; i < profileItems.length; i++)
                              _buildProfileItem(
                                context,
                                profileItems[i],
                                hScale: hScale,
                                isLast: i == profileItems.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    
                    // App Version Display
                    Center(
                      child: appVersionAsync.when(
                        data: (version) => Text(
                          'Version $version',
                          style: TextStyle(
                            fontSize: 12 * hScale.clamp(0.9, 1.1),
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
        const PendingCashPaymentOverlay(),
      ],
    );
  }

  Widget _buildProfileItem(
    BuildContext context,
    _ProfileItemConfig item, {
    required double hScale,
    bool isLast = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Rounded container for the icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: 24 * hScale.clamp(0.9, 1.1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title and Subtitle details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16 * hScale.clamp(0.9, 1.1),
                          fontWeight: FontWeight.w600,
                          color: item.isDestructive
                              ? Colors.red.shade600
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12 * hScale.clamp(0.9, 1.1),
                          color: item.isDestructive
                              ? Colors.red.shade300
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing Arrow icon
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20 * hScale.clamp(0.9, 1.1),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: Colors.grey.shade100,
            height: 1,
            indent: 84, // Aligns perfectly after the leading icon box
            endIndent: 20,
          ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Strictly sign out from both providers
                await ref.read(authViewModelProvider.notifier).signOut();
                
                if (context.mounted) {
                  // Force redirection to LoginScreen and clear all previous routes
                  // We use the root navigator to ensure the entire app state is reset
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ProfileItemConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isDestructive;

  _ProfileItemConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
    this.isDestructive = false,
  });
}
