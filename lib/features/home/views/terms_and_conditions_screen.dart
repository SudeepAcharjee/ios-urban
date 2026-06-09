import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

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
          'Terms & Conditions',
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
              'Terms and Conditions',
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
              'Welcome to Urban Service. By booking or using our services, you agree to the following Terms and Conditions.',
              style: TextStyle(
                color: textPrimary,
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader('1. Services Offered'),
            _buildParagraph(
              'Urban Service provides doorstep services including but not limited to:\n\n'
              '•  Car washing and detailing\n'
              '•  Bike washing and servicing\n'
              '•  Electrical repair and maintenance services\n'
              '•  General doorstep maintenance services\n\n'
              'Services are provided at the customer’s selected location subject to availability.',
            ),

            _buildSectionHeader('2. Customer Responsibilities'),
            _buildParagraph(
              'Customers must ensure:\n'
              '•  Proper and safe access to the service location\n'
              '•  Availability of the vehicle or equipment during the scheduled service time\n'
              '•  Cooperation with service professionals during the service process',
            ),
            const SizedBox(height: 15),
            // Important Alert Box
            _buildAlertBox(
              title: 'Important Note',
              icon: Icons.warning_amber_rounded,
              color: Colors.amber.shade900,
              bgColor: Colors.amber.shade50,
              content: 'Urban Service does not provide:\n'
                  '•  Water supply\n'
                  '•  Electricity supply\n'
                  '•  Washing space or cleaning area\n\n'
                  'Customers must arrange these requirements before the service begins.',
            ),
            const SizedBox(height: 25),

            _buildSectionHeader('3. Booking and Payments'),
            _buildParagraph(
              '•  Service bookings are confirmed only after successful scheduling through the app or platform.\n'
              '•  Prices may vary depending on service type, location, and additional requirements.\n'
              '•  Payments must be completed through approved payment methods available in the app.',
            ),

            _buildSectionHeader('4. Cancellation and Rescheduling'),
            _buildParagraph(
              '•  Customers may cancel or reschedule within the allowed time shown in the app.\n'
              '•  Late cancellations may result in cancellation charges.',
            ),

            _buildSectionHeader('5. Service Limitations'),
            _buildParagraph(
              'Urban Service aims to provide professional and safe services; however:\n'
              '•  Results may vary depending on vehicle condition, equipment condition, or external factors.\n'
              '•  Certain damages or issues existing before the service may not be reversible.',
            ),

            _buildSectionHeader('6. Damage Compensation Policy'),
            _buildParagraph(
              'In the rare event of damage caused directly by our service professionals during the service process:\n'
              '•  Customers must report the issue immediately with proper evidence (photos/videos).\n'
              '•  Urban Service will review the claim internally.',
            ),
            const SizedBox(height: 15),
            // Compensation Cap Alert Box
            _buildAlertBox(
              title: 'Compensation Limit',
              icon: Icons.gpp_maybe_rounded,
              color: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
              content: 'If the claim is verified, compensation may be provided up to a maximum amount of ₹1500 (One Thousand Five Hundred Rupees) only.',
            ),
            const SizedBox(height: 15),
            _buildParagraph(
              'Urban Service shall not be responsible for:\n'
              '•  Pre-existing damage\n'
              '•  Mechanical failures unrelated to the service\n'
              '•  Indirect or consequential losses\n'
              '•  Personal belongings left inside vehicles',
            ),
            const SizedBox(height: 10),

            _buildSectionHeader('7. Service Refusal Rights'),
            _buildParagraph(
              'Urban Service reserves the right to refuse or stop service if:\n'
              '•  The location is unsafe\n'
              '•  Required utilities are unavailable\n'
              '•  Customers behave abusively or inappropriately\n'
              '•  Conditions may risk staff safety or equipment damage',
            ),

            _buildSectionHeader('8. Warranty Disclaimer'),
            _buildParagraph(
              'All services are provided on a reasonable-effort basis. Urban Service does not provide guarantees or warranties unless specifically mentioned for a particular service.',
            ),

            _buildSectionHeader('9. Privacy'),
            _buildParagraph(
              'Customer information collected during booking and service operations will be handled responsibly and used only for operational, support, and communication purposes.',
            ),

            _buildSectionHeader('10. Changes to Terms'),
            _buildParagraph(
              'Urban Service may update these Terms and Conditions at any time without prior notice. Continued use of the app or services indicates acceptance of updated terms.',
            ),

            _buildSectionHeader('11. Contact Information'),
            _buildParagraph(
              'For support, complaints, or service-related issues, customers may contact Urban Service through the official app or customer support channels.',
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 25),
            const Center(
              child: Text(
                'By using Urban Service, you acknowledge that you have read, understood, and agreed to these Terms and Conditions.',
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
