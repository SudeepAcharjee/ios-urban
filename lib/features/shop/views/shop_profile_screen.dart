import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/widgets/role_tab_bar.dart';
import '../../home/views/my_reviews_screen.dart';
import '../../../core/providers/app_info_provider.dart';
import 'shop_payment_details_screen.dart';
import 'shop_documents_screen.dart';
import 'shop_info_edit_screen.dart';
import 'shop_terms_and_conditions_screen.dart';
import 'shop_privacy_policy_screen.dart';
import '../../home/views/raise_ticket_screen.dart';

class _ShopProfileItemConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ShopProfileItemConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
    this.isDestructive = false,
  });
}

class ShopProfileScreen extends ConsumerWidget {
  final bool showBackButton;
  const ShopProfileScreen({super.key, this.showBackButton = true});

  static const primaryColor = Color(0xFF2029C5);

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your Shop account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext, rootNavigator: true).pop();
              try {
                await ref.read(authViewModelProvider.notifier).signOut();
              } catch (_) {}
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(initialRole: AuthRole.shop),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final appVersionAsync = ref.watch(appVersionProvider);
    final Size size = MediaQuery.of(context).size;
    final double screenHeight = size.height;
    final double screenWidth = size.width;
    final double hScale = screenHeight / 812.0;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Authentication required')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shops').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final shopData = snapshot.data?.data() ?? {};
        final shopName = (shopData['shopName'] ?? shopData['businessName'] ?? 'Workshop').toString();
        final ownerName = (shopData['ownerName'] ?? shopData['name'] ?? 'Owner').toString();
        final shopPhoto = shopData['shopPhoto'] ?? shopData['profilePic'];
        final serviceType = (shopData['serviceType'] ?? 'Car & Bike Servicing').toString();

        // Profile items modeled after worker_profile_screen.dart
        final profileItems = [
          _ShopProfileItemConfig(
            icon: Icons.storefront_outlined,
            title: 'Shop Information',
            subtitle: 'View workshop contact, address & GPS',
            iconColor: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopInfoEditScreen()),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.verified_user_outlined,
            title: 'Verified Documents',
            subtitle: 'Trade license, GST & business permits',
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopDocumentsScreen()),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payment Info',
            subtitle: 'View earnings, commissions & settlements',
            iconColor: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF5F3FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopPaymentDetailsScreen(showBackButton: true)),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.star_outline_rounded,
            title: 'Customer Reviews',
            subtitle: 'See customer ratings & feedback',
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFEF3C7),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyReviewsScreen(isShop: true)),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.support_agent_rounded,
            title: 'Help & Support',
            subtitle: 'Raise ticket to admin & get help',
            iconColor: const Color(0xFF06B6D4),
            bgColor: const Color(0xFFECFEFF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RaiseTicketScreen()),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Workshop partner terms of service',
            iconColor: const Color(0xFF6B7280),
            bgColor: const Color(0xFFF3F4F6),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopTermsAndConditionsScreen()),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Workshop partner privacy policy',
            iconColor: const Color(0xFF14B8A6),
            bgColor: const Color(0xFFF0FDFA),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopPrivacyPolicyScreen()),
            ),
          ),
          _ShopProfileItemConfig(
            icon: Icons.logout_outlined,
            title: 'Logout',
            subtitle: 'Sign out of your shop account',
            iconColor: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            isDestructive: true,
            onTap: () => _showLogoutDialog(context, ref),
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8FAFC),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leading: showBackButton
                ? IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
                    ),
                  )
                : null,
            title: const Text(
              'Shop Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              top: screenHeight * 0.01,
              bottom: screenHeight * 0.04,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Profile Header Card with Gradient and Concentric Rings
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [
                        primaryColor,
                        Color(0xFF4F46E5),
                      ],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
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
                                  color: Colors.white.withValues(alpha: 0.08),
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
                                  color: Colors.white.withValues(alpha: 0.06),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                          child: Row(
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: shopPhoto != null && shopPhoto.toString().isNotEmpty
                                      ? Image.network(
                                          shopPhoto.toString(),
                                          fit: BoxFit.cover,
                                          width: 76,
                                          height: 76,
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.storefront_rounded,
                                            size: 40,
                                            color: primaryColor,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.storefront_rounded,
                                          size: 40,
                                          color: primaryColor,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      shopName,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'Owner: $ownerName',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      serviceType,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                SizedBox(height: screenHeight * 0.025),

                // Action Items Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
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
                SizedBox(height: screenHeight * 0.03),

                // App Version
                Center(
                  child: appVersionAsync.when(
                    data: (version) => Text(
                      'Urban Service • Version $version',
                      style: TextStyle(
                        fontSize: 12 * hScale.clamp(0.9, 1.1),
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(
    BuildContext context,
    _ShopProfileItemConfig item, {
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
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item.icon,
                      color: item.iconColor,
                      size: 22 * hScale.clamp(0.9, 1.1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15 * hScale.clamp(0.9, 1.1),
                          fontWeight: FontWeight.w600,
                          color: item.isDestructive ? Colors.red.shade600 : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 12 * hScale.clamp(0.9, 1.1),
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 82),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
      ],
    );
  }
}
