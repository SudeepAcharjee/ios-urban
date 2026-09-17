import 'package:flutter/material.dart';

class ShopPrivacyPolicyScreen extends StatelessWidget {
  const ShopPrivacyPolicyScreen({super.key});

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
          'Partner Privacy Policy',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Badge & Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'Partner Data & Privacy Standards',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Privacy Policy for Workshop Partners',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Urban Service Platform',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Effective Date: January 1, 2026 • Version 2.4',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF3F4F6), thickness: 1.5),
            const SizedBox(height: 16),

            // Intro Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'This Partner Privacy Policy explains how Urban Service collects, stores, processes, and protects the business, personal, financial, and operational data of registered Workshop Partners, mechanics, and garage operators across our mobile applications and administration platforms.',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 1
            _buildSection(
              number: '1',
              title: 'Information We Collect from Workshop Partners',
              content:
                  'To establish and verify your workshop on Urban Service, we collect:\n\n'
                  '• Business Identity: Workshop/Company name, registered address, operational hours, workshop photos, facility amenities, and geographic coordinates.\n'
                  '• Owner & Legal Documentation: Owner name, contact phone number, email address, Trade License copy, Business PAN, GSTIN certificate, and identity verification credentials.\n'
                  '• Banking & Payout Data: Bank account number, IFSC code, account holder name, and UPI identifiers for automated revenue disbursement.\n'
                  '• Operational & Performance Data: Service catalogs, pricing, booking histories, turnaround times, customer reviews, ratings, and dispute records.',
            ),

            // Section 2
            _buildSection(
              number: '2',
              title: 'How Partner Information is Used',
              content:
                  'We utilize your data to facilitate efficient platform operations:\n\n'
                  '• Customer Discovery: Displaying your workshop listing, services, distance, user reviews, and pricing to customers searching for nearby car/bike services.\n'
                  '• Booking Routing & Communication: Delivering booking alerts, in-app messaging, and service completion workflows.\n'
                  '• Financial Settlements: Computing earnings, generating tax invoices, collecting platform commissions, and processing direct bank transfers.\n'
                  '• Quality Control & Security: Preventing fraudulent activity, ensuring regulatory compliance, and maintaining vehicle safety standards.',
            ),

            // Section 3
            _buildSection(
              number: '3',
              title: 'Public vs. Private Information Disclosure',
              content:
                  '• Publicly Displayed on App: Your workshop name, cover photos, listed services, customer ratings, public reviews, business address, and map location are publicly visible to customers.\n'
                  '• Strictly Confidential: Your government IDs, Trade License files, tax documentation, bank account numbers, commission settlement records, and private chat logs are securely encrypted and accessible only to authorized Urban Service compliance officers.',
            ),

            // Section 4
            _buildSection(
              number: '4',
              title: 'Before-Service Inspection Photos & 7-Day Auto-Deletion',
              content:
                  '• Purpose of Inspection Photos: Before starting work, photos of the customer vehicle condition are captured by the workshop to establish pre-existing damages and prevent unfair dispute claims.\n'
                  '• Retention Period: Before-service inspection photos are transmitted to the secure admin repository and retained for exactly seven (7) days.\n'
                  '• Automatic Deletion: After 7 days from the service start timestamp, inspection photo URLs and associated storage assets are automatically purged and permanently deleted from platform servers, minimizing storage footprints and protecting customer privacy.',
            ),

            // Section 5
            _buildSection(
              number: '5',
              title: 'Data Security & Storage Safeguards',
              content:
                  '• Industry-Standard Encryption: All partner data in transit is encrypted using TLS 1.3, and databases are protected using enterprise AES-256 cloud encryption.\n'
                  '• Cloud Storage: Static assets, KYC documents, and proof images are hosted on secure, ISO-certified Cloudinary and Google Cloud Firebase storage clusters with restricted access tokens.\n'
                  '• Access Control: Only vetted administrative personnel with two-factor authentication (2FA) have access to partner verification records.',
            ),

            // Section 6
            _buildSection(
              number: '6',
              title: 'Partner Data Rights & Account Management',
              content:
                  'As a Workshop Partner, you have full control over your business data:\n\n'
                  '• Information Updates: Edit and update your workshop phone numbers, pricing, service catalogs, photos, and address anytime via the Partner Profile.\n'
                  '• Payout Information Modification: Submit verified requests to update bank account details via the Partner Support Desk.\n'
                  '• Account Deletion & Right to be Forgotten: Request account closure and deletion of non-essential records by raising a ticket under Help & Support.',
            ),

            // Section 7
            _buildSection(
              number: '7',
              title: 'Contact Our Data Protection Officer',
              content:
                  'For inquiries regarding this Partner Privacy Policy or data security practices, please contact our compliance desk:\n\n'
                  '• Privacy Inquiries: privacy@urbanservice.co.in\n'
                  '• Partner Support Desk: In-App "Raise Ticket"\n'
                  '• Corporate Office: Urban Service Technologies India Pvt. Ltd., Auto Hub Tech Park, India.',
            ),

            const SizedBox(height: 30),

            // Security Badge
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Color(0xFF16A34A), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your business information is handled with enterprise-grade privacy and encryption standards.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSection({
    required String number,
    required String title,
    required String content,
  }) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF4B5563);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              content,
              style: const TextStyle(
                color: textSecondary,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
