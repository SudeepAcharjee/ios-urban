import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    const primaryColor = Color(0xFF2029C5);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 16),
          ),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Effective Date
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Urban Service',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Effective Date: May 17, 2026',
              style: TextStyle(
                color: textSecondary.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This Privacy Policy explains how Urban Service collects, uses, stores, and protects user information when customers use our mobile application, website, or services.\n\n'
              'By using Urban Service, you agree to the practices described in this Privacy Policy.',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('1. Information We Collect'),
            _buildSubHeader('Personal Information'),
            _buildParagraph(
              '•  Full name\n'
              '•  Phone number\n'
              '•  Email address\n'
              '•  Address and service location',
            ),
            const SizedBox(height: 15),
            _buildSubHeader('Booking Information'),
            _buildParagraph(
              '•  Service history\n'
              '•  Vehicle details\n'
              '•  Appointment schedules\n'
              '•  Payment information',
            ),
            const SizedBox(height: 15),
            _buildSubHeader('Device & Technical Information'),
            _buildParagraph(
              '•  Device type\n'
              '•  IP address\n'
              '•  App usage data\n'
              '•  Operating system information',
            ),

            _buildSectionHeader('2. How We Use Your Information'),
            _buildParagraph(
              'Urban Service uses collected information to:\n'
              '•  Provide and manage services\n'
              '•  Schedule and complete bookings\n'
              '•  Process payments\n'
              '•  Improve app functionality and user experience\n'
              '•  Contact customers regarding bookings, updates, or support\n'
              '•  Prevent fraud and misuse of services',
            ),

            _buildSectionHeader('3. Location Access'),
            _buildParagraph(
              'The app may request location access to:\n'
              '•  Detect service availability\n'
              '•  Provide accurate doorstep services\n'
              '•  Improve booking accuracy',
            ),
            const SizedBox(height: 15),
            _buildAlertBox(
              title: 'Location Permissions Notice',
              icon: Icons.location_on_rounded,
              color: Colors.blue.shade900,
              bgColor: Colors.blue.shade50,
              content: 'Users may disable location permissions, but some crucial features (like automatic address detection) may not function properly.',
            ),
            const SizedBox(height: 25),

            _buildSectionHeader('4. Payment Information'),
            _buildParagraph(
              'Payments are processed through secure third-party payment providers.',
            ),
            const SizedBox(height: 15),
            _buildAlertBox(
              title: 'Secure Payment Guarantee',
              icon: Icons.security_rounded,
              color: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              content: 'Urban Service does not store sensitive card or banking details directly on its servers. All payments are encrypted end-to-end.',
            ),
            const SizedBox(height: 25),

            _buildSectionHeader('5. Data Sharing'),
            _buildParagraph(
              'Urban Service does not sell customer data.\n\n'
              'Information may be shared only with:\n'
              '•  Service professionals assigned to bookings\n'
              '•  Payment gateway providers\n'
              '•  Legal authorities when required by law',
            ),

            _buildSectionHeader('6. Data Security'),
            _buildParagraph(
              'We take reasonable security measures to protect customer information from unauthorized access, misuse, or disclosure. However, no internet-based platform can guarantee complete security.',
            ),

            _buildSectionHeader('7. Cookies and Analytics'),
            _buildParagraph(
              'Urban Service may use cookies, analytics tools, and similar technologies to:\n'
              '•  Improve app performance\n'
              '•  Understand user behavior\n'
              '•  Enhance customer experience',
            ),

            _buildSectionHeader('8. User Responsibilities'),
            _buildParagraph(
              'Users are responsible for:\n'
              '•  Providing accurate information\n'
              '•  Maintaining account confidentiality\n'
              '•  Using the app lawfully and responsibly',
            ),

            _buildSectionHeader('9. Children\'s Privacy'),
            _buildParagraph(
              'Urban Service services are not intended for individuals under 18 years of age. We do not knowingly collect personal information from minors.',
            ),

            _buildSectionHeader('10. Third-Party Services'),
            _buildParagraph(
              'Our app may include links or integrations with third-party services. Urban Service is not responsible for the privacy practices of external platforms.',
            ),

            _buildSectionHeader('11. Data Retention'),
            _buildParagraph(
              'We may retain customer information for operational, legal, security, and business purposes as required.',
            ),

            _buildSectionHeader('12. Changes to This Privacy Policy'),
            _buildParagraph(
              'Urban Service may update this Privacy Policy at any time. Updated versions will be posted within the app or website.',
            ),

            _buildSectionHeader('13. Contact Us'),
            _buildParagraph(
              'For questions, support, or privacy-related concerns, users may contact Urban Service through the official application or customer support channels.',
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 25),
            const Center(
              child: Text(
                'By using Urban Service, you acknowledge that you have read and agreed to this Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2029C5),
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4B5563),
        fontSize: 14,
        height: 1.7,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildAlertBox({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
