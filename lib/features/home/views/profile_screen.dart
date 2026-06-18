import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';

import 'edit_profile_screen.dart';
import 'add_vehicle_screen.dart';
import 'help_support_screen.dart';
import 'bookings_screen.dart';
import 'terms_and_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import 'add_card_screen.dart';
import 'add_address_screen.dart';
import 'bookmarks_screen.dart';
import 'my_reviews_screen.dart';
import '../../../core/providers/app_info_provider.dart';



class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
        icon: Icons.directions_car_outlined,
        title: 'My Vehicles',
        subtitle: 'Manage your added vehicles',
        iconColor: const Color(0xFF10B981), // Green
        bgColor: const Color(0xFFECFDF5), // Light Green
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVehicleScreen(showAddedVehiclesFirst: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.calendar_today_outlined,
        title: 'My Bookings',
        subtitle: 'View your booking history',
        iconColor: const Color(0xFF8B5CF6), // Purple
        bgColor: const Color(0xFFF5F3FF), // Light Purple
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingsScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.rate_review_outlined,
        title: 'My Reviews',
        subtitle: 'See your reviews & ratings',
        iconColor: const Color(0xFFF59E0B), // Amber
        bgColor: const Color(0xFFFEF3C7), // Light Amber
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyReviewsScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.credit_card_outlined,
        title: 'Payment Methods',
        subtitle: 'Manage your payment options',
        iconColor: const Color(0xFF3B82F6), // Blue
        bgColor: const Color(0xFFEFF6FF), // Light Blue
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCardScreen(title: 'Payment Methods', showAddedCardsFirst: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.location_on_outlined,
        title: 'Addresses',
        subtitle: 'Manage your saved addresses',
        iconColor: const Color(0xFFEF4444), // Red
        bgColor: const Color(0xFFFEF2F2), // Light Red
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddAddressScreen(title: 'My Addresses', showAddedAddressesFirst: true))),
      ),
      _ProfileItemConfig(
        icon: Icons.bookmark_border_rounded,
        title: 'Bookmarks',
        subtitle: 'View your saved listings',
        iconColor: const Color(0xFFEC4899), // Pink
        bgColor: const Color(0xFFFDF2F8), // Light Pink
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.help_outline_rounded,
        title: 'Help & Support',
        subtitle: 'Get help and contact support',
        iconColor: const Color(0xFF06B6D4), // Cyan
        bgColor: const Color(0xFFECFEFF), // Light Cyan
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.description_outlined,
        title: 'Terms & Conditions',
        subtitle: 'Read our terms and conditions',
        iconColor: const Color(0xFF6B7280), // Slate/Grey
        bgColor: const Color(0xFFF3F4F6), // Light Grey
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsAndConditionsScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'Read our privacy policy',
        iconColor: const Color(0xFF14B8A6), // Teal
        bgColor: const Color(0xFFF0FDFA), // Light Teal
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())),
      ),
      _ProfileItemConfig(
        icon: Icons.delete_outline_rounded,
        title: 'Delete Account',
        subtitle: 'Permanently delete your account',
        iconColor: const Color(0xFFEF4444), // Red
        bgColor: const Color(0xFFFEF2F2), // Light Red
        isDestructive: true,
        onTap: () => _showDeleteAccountDialog(context, ref),
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

    return Scaffold(
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
          final name = userData?['name'] ?? 'User Name';
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
                                            'Manage Account',
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
            indent: 84, // Aligns perfectly after the leading icon box (48 width + 20 horizontal padding + 16 gap)
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
              Navigator.pop(context);
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is permanent and all your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the confirmation dialog
              
              // Show a loading dialog so the user gets visual feedback immediately
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const PopScope(
                  canPop: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              );

              try {
                await ref.read(authViewModelProvider.notifier).deleteAccount();
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss the loading dialog
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Dismiss the loading dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Error'),
                      content: Text(e.toString()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
