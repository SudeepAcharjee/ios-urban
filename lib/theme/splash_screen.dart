import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../features/onboarding/views/onboarding_screen.dart';
import '../features/home/views/main_screen.dart';
import '../features/auth/views/login_screen.dart';
import '../features/auth/views/complete_profile_screen.dart';
import '../features/auth/views/otp_screen.dart';
import '../features/auth/views/location_request_screen.dart';
import '../features/auth/views/notification_request_screen.dart';
import '../core/services/preference_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../features/worker/views/worker_main_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.linear,
      ),
    );

    _progressController.forward();

    _checkState();
  }

  void _checkState() {
    // Navigate with a smooth Fade Transition
    Timer(const Duration(milliseconds: 3500), () async {
      if (mounted) {
        // 🏗️ Check for Maintenance Mode first
        try {
          final maintenanceDoc = await FirebaseFirestore.instance.collection('maintenance').doc('system').get();
          if (maintenanceDoc.exists && (maintenanceDoc.data()?['maintenanceMode'] ?? false)) {
            if (mounted) {
              _showMaintenanceDialog(context);
            }
            return;
          }
        } catch (e) {
          debugPrint("Error checking maintenance mode: $e");
        }

        final user = FirebaseAuth.instance.currentUser;
        final onboardingComplete = await PreferenceService.isOnboardingComplete();
        
        Widget targetScreen;
        if (user != null) {
          // If logged in, check profile completion status in both collections
          try {
            final String uid = user.uid;
            var doc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
            bool isWorker = doc.exists;

            if (!isWorker) {
              doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            }

            final data = doc.data();
            if (data == null) {
              targetScreen = const CompleteProfileScreen();
            } else if (data['status'] == 'Blocked') {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                _showBlockedDialog(context);
              }
              return;
            } else {
              // 🔄 Unified Profile Completion Logic for both Workers and Users
              final bool isWorkerRole = data['role']?.toString().toLowerCase() == 'worker' || isWorker;
              
              // Workers are considered complete if they have name and phone
              // Users also need gender for their profile to be complete
              final bool hasProfile = isWorkerRole 
                  ? (data['name'] != null && data['phone'] != null)
                  : (data['gender'] != null);
                  
              final bool hasLocation = data['location'] != null || data['latitude'] != null;
              final bool hasNotifications = data['notificationsEnabled'] != null;

              final bool isOtpVerified = data['isOtpVerified'] ?? true;

              if (!isOtpVerified) {
                targetScreen = OtpScreen(
                  email: data['email'] ?? '',
                  isRegistration: !hasProfile,
                );
              } else if (!hasProfile) {
                targetScreen = const CompleteProfileScreen();
              } else if (isWorkerRole) {
                // Workers go straight to their dashboard after profile completion
                targetScreen = const WorkerMainScreen();
              } else if (!hasLocation) {
                targetScreen = const LocationRequestScreen();
              } else if (!hasNotifications) {
                targetScreen = const NotificationRequestScreen();
              } else {
                targetScreen = const MainScreen();
              }
            }


          } catch (e) {
            // Fallback to main screen if firestore fetch fails
            targetScreen = const MainScreen();
          }
        } else if (!onboardingComplete) {
          targetScreen = const OnboardingScreen();
        } else {
          targetScreen = const LoginScreen();
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    });
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
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.construction_rounded, color: Color(0xFF2029C5)),
            const SizedBox(width: 10),
            const Text('Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Our services are currently under scheduled maintenance to provide you with a better experience. We will be back shortly!',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Option to check again or close app
              Navigator.of(context).pop();
              _checkState(); // Retry
            },
            child: const Text('Check Again', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2029C5))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
            // Logo
            Center(
              child: Image.asset(
                'images/logo/Urban Services-2.png',
                height: MediaQuery.of(context).size.height * 0.18,
                fit: BoxFit.contain,
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Illustration
            Center(
              child: Image.asset(
                'images/car_wash_splash.png',
                height: MediaQuery.of(context).size.height * 0.32,
                fit: BoxFit.contain,
              ),
            ),
            
            const Spacer(flex: 3),
            
            // Tagline
            const Text(
              'Making every drive\na cleaner experience.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2029C5),
                height: 1.3,
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
            // Progress Bar
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    Container(
                      height: 6,
                      width: MediaQuery.of(context).size.width * 0.6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2029C5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progressAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2029C5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            SizedBox(height: MediaQuery.of(context).size.height * 0.04),
          ],
        ),
      ),
    );
  }
}
