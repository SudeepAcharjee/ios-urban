import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_screen.dart';

class PendingCashPaymentOverlay extends ConsumerWidget {
  const PendingCashPaymentOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);

    return userDataAsync.when(
      data: (userData) {
        final status = userData?['status'] as String? ?? 'Active';
        if (status.toLowerCase() != 'disabled') {
          return const SizedBox.shrink();
        }

        return PopScope(
          canPop: false,
          child: GestureDetector(
            onTap: () {}, // Intercept tap gestures to prevent interaction with underlying UI
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              backgroundColor: Colors.black.withOpacity(0.65),
              body: Stack(
                children: [
                  // Backdrop Blur Effect
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),
                  
                  // Central Card
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Exclamation/Warning Lock Icon
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Title
                          const Text(
                            'Account Deactivated',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // Message Highlight
                          const Text(
                            'Please release the pending cash payment.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFEF4444),
                              height: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          
                          // Subtext description
                          const Text(
                            'Your account has been temporarily disabled by the administration. To restore access and continue receiving bookings, please settle any pending cash payments with the administrator.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Logout button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                try {
                                  await ref.read(authViewModelProvider.notifier).signOut();
                                  if (context.mounted) {
                                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      (route) => false,
                                    );
                                  }
                                } catch (_) {}
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.2)),
                                ),
                              ),
                              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                              label: const Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
