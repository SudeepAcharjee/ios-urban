import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/custom_toast.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';
import '../../auth/views/widgets/role_tab_bar.dart';
import 'shop_main_screen.dart';
import 'shop_onboarding_screen.dart';

class ShopWaitingApprovalScreen extends ConsumerStatefulWidget {
  const ShopWaitingApprovalScreen({super.key});

  @override
  ConsumerState<ShopWaitingApprovalScreen> createState() => _ShopWaitingApprovalScreenState();
}

class _ShopWaitingApprovalScreenState extends ConsumerState<ShopWaitingApprovalScreen> {
  static const primaryColor = Color(0xFF2029C5);
  bool _isChecking = false;

  Future<void> _checkStatusManually() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isChecking = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
      if (!mounted) return;

      if (!doc.exists) {
        CustomToast.error(context, 'Shop profile not found');
        return;
      }

      final data = doc.data() ?? {};
      final status = (data['status'] ?? 'pending').toString().toLowerCase();

      if (status == 'active' || status == 'approved') {
        CustomToast.success(context, 'Congratulations! Your shop is approved!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ShopMainScreen()),
          (route) => false,
        );
      } else if (status == 'rejected') {
        CustomToast.error(context, 'Your application was rejected. Please review details.');
      } else {
        CustomToast.info(context, 'Your application is still under review by Admin.');
      }
    } catch (e) {
      if (mounted) CustomToast.error(context, 'Failed to check status: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showLogoutDialog() {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out from your shop account?'),
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
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('shops').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: primaryColor)),
          );
        }

        final data = snapshot.data?.data() ?? {};
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final isRejected = status == 'rejected';
        final rejectionReason = data['rejectionReason'] as String? ?? 'Incomplete or invalid documents submitted.';
        final shopName = data['shopName'] as String? ?? 'Your Shop';
        final ownerName = data['ownerName'] as String? ?? data['name'] as String? ?? '';
        final phone = data['phone'] as String? ?? '';
        final serviceType = data['serviceType'] as String? ?? '';

        // Auto redirect if approved
        if (status == 'active' || status == 'approved') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const ShopMainScreen()),
                (route) => false,
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: null,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.black87),
                tooltip: 'Log Out',
                onPressed: _showLogoutDialog,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status Badge Icon
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isRejected
                            ? Colors.red.shade50
                            : const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isRejected ? Colors.red : Colors.amber).withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isRejected
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top_rounded,
                          size: 56,
                          color: isRejected ? Colors.red.shade600 : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    Text(
                      isRejected ? 'Application Rejected' : 'Admin Will Approve Your Request',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle / Notice
                    Text(
                      isRejected
                          ? 'Unfortunately, your shop application could not be approved at this time.'
                          : 'Your shop details and legal documents have been submitted successfully. Please wait while our admin team reviews your application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Rejection reason card if rejected
                    if (isRejected) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline_rounded, size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Reason for Rejection',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rejectionReason,
                              style: TextStyle(fontSize: 13, color: Colors.red.shade900, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Shop Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'APPLICATION DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isRejected
                                      ? Colors.red.shade50
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isRejected
                                        ? Colors.red.shade200
                                        : const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  isRejected ? 'REJECTED' : 'PENDING APPROVAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isRejected
                                        ? Colors.red.shade700
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Shop Name', shopName, Icons.storefront_rounded),
                          _buildDetailRow('Owner Name', ownerName, Icons.person_outline_rounded),
                          _buildDetailRow('Contact Phone', phone, Icons.phone_outlined),
                          _buildDetailRow('Service Type', serviceType, Icons.build_circle_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Button (Check Status or Re-edit)
                    if (isRejected)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ShopOnboardingScreen(initialShopData: data),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text(
                            'Update Details & Resubmit',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isChecking ? null : _checkStatusManually,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isChecking ? 'Checking...' : 'Check Status',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Log Out Text Button
                    TextButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: Icon(Icons.logout_rounded, size: 16, color: Colors.grey.shade600),
                      label: Text(
                        'Log Out',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 1),
                Text(
                  value.isEmpty ? '—' : value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
