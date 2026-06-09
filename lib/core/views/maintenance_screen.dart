import 'package:flutter/material.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🏗️ Maintenance Illustration (Lottie or Icon)
              Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.construction_rounded,
                    size: 100,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // 📝 Title
              const Text(
                'Under Maintenance',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 15),
              
              // 📄 Subtitle
              const Text(
                'We are currently performing scheduled maintenance to improve our services. We\'ll be back online shortly!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // ⏳ Estimated Time or Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 20, color: textPrimary),
                    const SizedBox(width: 10),
                    const Text(
                      'Back in: ~ 2 Hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // 📞 Support Link
              const Text(
                'Need urgent help?',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              TextButton(
                onPressed: () {
                  // Add support action
                },
                child: const Text(
                  'Contact Support',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
