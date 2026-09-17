import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/custom_toast.dart';
import '../../home/views/main_screen.dart';
import '../../worker/views/worker_main_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class NotificationRequestScreen extends ConsumerWidget {
  const NotificationRequestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double hScale = size.height / 812.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Notification Illustration
              Container(
                width: 180 * hScale.clamp(0.8, 1.2),
                height: 180 * hScale.clamp(0.8, 1.2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.notifications_active,
                    size: 80 * hScale.clamp(0.8, 1.2),
                    color: primaryColor,
                  ),
                ),
              ),
              
              SizedBox(height: 50 * hScale),
              
              Text(
                'Turn on Notifications?',
                style: TextStyle(
                  fontSize: 26 * hScale.clamp(0.9, 1.1),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              
              SizedBox(height: 15 * hScale),
              
              Text(
                'To Receive Updates and Booking Status.',
                style: TextStyle(
                  fontSize: 16 * hScale.clamp(0.9, 1.1),
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: (55 * hScale).clamp(55, 70),
                child: ElevatedButton(
                  onPressed: ref.watch(authViewModelProvider).isLoading
                    ? null
                    : () async {
                        try {
                          // 1. Request Permission
                          bool granted = await NotificationService.requestPermission();
                          
                          if (granted) {
                            // 2. Get Token
                            String? token = await NotificationService.getToken();
                            if (token != null) {
                              await ref.read(authViewModelProvider.notifier).updateProfile({
                                'fcmToken': token,
                                'notificationsEnabled': true,
                              });
                            }
                            CustomToast.success(context, 'Notifications enabled!');
                          } else {
                            CustomToast.warning(context, 'Notification permission denied.');
                          }
                          
                          if (context.mounted) {
                            await _navigateToHome(context, ref);
                          }
                        } catch (e) {
                          if (context.mounted) CustomToast.error(context, e.toString());
                        }
                      },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryColor.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: ref.watch(authViewModelProvider).isLoading
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
                            'Processing...',
                            style: TextStyle(fontSize: 18 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Text(
                        'Allow Notification Access',
                        style: TextStyle(fontSize: 18 * hScale.clamp(0.9, 1.1), fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              
              SizedBox(height: 15 * hScale),
              
              TextButton(
                onPressed: () => _navigateToHome(context, ref),

                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 16 * hScale.clamp(0.9, 1.1),
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              SizedBox(height: 30 * hScale),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToHome(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final String uid = user.uid;
      var doc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
      bool isWorker = doc.exists;

      if (!isWorker) {
        doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      }

      final data = doc.data();
      final String role = data?['role']?.toString().toLowerCase() ?? 'user';

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => role == 'worker' ? const WorkerMainScreen() : const MainScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    }
  }
}

