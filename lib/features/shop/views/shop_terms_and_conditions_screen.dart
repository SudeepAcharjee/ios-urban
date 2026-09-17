import 'package:flutter/material.dart';

class ShopTermsAndConditionsScreen extends StatelessWidget {
  const ShopTermsAndConditionsScreen({super.key});

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
          'Partner Terms & Conditions',
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
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 14, color: primaryColor),
                  SizedBox(width: 6),
                  Text(
                    'Workshop Partner Agreement',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Terms of Service for Workshop Partners',
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

            // Introduction Callout
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'This Workshop Partner Agreement ("Agreement") governs the relationship between Urban Service ("Platform", "We", "Us") and registered automotive workshops, garages, and service centers ("Workshop Partner", "Shop", "You"). By registering as a Workshop Partner, listing automotive services, or accepting customer bookings through the Urban Service application, you agree to be legally bound by these terms.',
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
              title: 'Workshop Eligibility & Onboarding',
              content:
                  'To operate as a verified Workshop Partner on Urban Service, you must satisfy the following criteria:\n\n'
                  '• Legal Registration: Provide valid business documentation, including Trade License, GST Registration (where applicable), Business PAN, and Owner Identity Proof (Aadhaar / Voter ID / Passport).\n'
                  '• Physical Premises: Maintain a physical, functional workshop facility equipped with standard tools, safety gear, and qualified automotive technicians.\n'
                  '• Verification Process: All submitted documents and workshop profiles undergo manual administrative inspection before listing activation.\n'
                  '• Accuracy of Information: You warrant that all information, business names, addresses, contact details, and geo-coordinates provided are authentic and up-to-date.',
            ),

            // Section 2
            _buildSection(
              number: '2',
              title: 'Service Listings, Pricing & Transparency',
              content:
                  '• Service Catalog: Workshop Partners are permitted to list standard automotive services, pricing, durations, and inclusions tailored to their expertise.\n'
                  '• Transparent Pricing: Listed prices must accurately reflect the base labor and service cost. Any mandatory additional parts or repairs identified during inspection must be communicated to the customer for prior approval before charging.\n'
                  '• No Hidden Charges: Unannounced surcharges, fraudulent part markups, or undisclosed fees violate platform policy and will lead to listing deactivation.',
            ),

            // Section 3
            _buildSection(
              number: '3',
              title: 'Booking Acceptance & Fulfillment Standards',
              content:
                  '• Acceptance Timeline: Workshops must accept or decline pending customer booking requests in a timely manner through the Partner Dashboard.\n'
                  '• Service Timelines: Once confirmed, the workshop must adhere to scheduled time slots and agreed delivery commitments.\n'
                  '• Customer Communication: Use in-app messaging and authorized phone calls solely for booking-related updates, service consultations, and repair authorizations.',
            ),

            // Section 4
            _buildSection(
              number: '4',
              title: 'Before-Service Inspection & Photo Verification',
              content:
                  '• Mandatory Inspection Proof: When starting any service, Workshop Partners are required to perform a pre-service inspection and capture vehicle condition photos via the app.\n'
                  '• Dispute Protection: These photos document pre-existing scratches, dents, fuel levels, odometer readings, and overall vehicle condition to safeguard both the workshop and the customer from false claims.\n'
                  '• 7-Day Safety Retention: Before-service inspection photos are transmitted securely to the platform administration and retained for exactly seven (7) days for verification and dispute resolution, after which they are permanently deleted in accordance with data retention policies.',
            ),

            // Section 5
            _buildSection(
              number: '5',
              title: 'Payments, Platform Commission & Settlement Cycles',
              content:
                  '• Payment Processing: Customers may pay online via platform gateways (Razorpay, UPI, Cards) or choose Cash on Service at the workshop.\n'
                  '• Platform Commission: Urban Service deducts an agreed platform service commission on completed bookings as specified in your Partner Dashboard settlement schedule.\n'
                  '• Direct Payouts: Net payout balances from online transactions are disbursed directly to your registered bank account on standard weekly/bi-weekly settlement cycles.\n'
                  '• Cash Bookings Reconciliation: For cash bookings collected in-person, platform commission deductions are adjusted against the partner balance or billed in the settlement cycle.',
            ),

            // Section 6
            _buildSection(
              number: '6',
              title: 'Workmanship Quality, Warranty & Customer Safety',
              content:
                  '• Standard of Work: All services must be executed with professional care using genuine OEM or high-grade compatible automotive parts.\n'
                  '• Service Warranty: Standard repair and detailing services must offer reasonable workmanship assurance as stated in the service description.\n'
                  '• Customer Property Protection: The workshop assumes responsibility for the safe custody and care of customer vehicles and personal belongings while inside the workshop premises.',
            ),

            // Section 7
            _buildSection(
              number: '7',
              title: 'Prohibited Practices & Penalties',
              content:
                  'Workshop Partners agree not to engage in any of the following prohibited behaviors:\n\n'
                  '• Off-Platform Solicitation: Attempting to circumvent the platform by encouraging customers to cancel app bookings and pay privately.\n'
                  '• Fraudulent Repairs: Billing for unperformed repairs, replacing functional genuine parts without consent, or using substandard counterfeit fluids.\n'
                  '• Abusive Conduct: Harassment, verbal abuse, or unprofessional behavior toward customers, platform representatives, or support agents.\n'
                  '• Multiple Cancellations: Repeatedly accepting and then cancelling bookings without justifiable cause.',
            ),

            // Section 8
            _buildSection(
              number: '8',
              title: 'Account Suspension & Termination',
              content:
                  '• Temporary Suspension: Urban Service reserves the right to suspend workshop access upon receipt of valid customer dispute reports, fraudulent billing complaints, or pending KYC reverification.\n'
                  '• Permanent Termination: Severe breaches, trade license invalidation, repeated customer safety violations, or criminal misconduct will result in permanent account termination and forfeiture of pending dispute claims.\n'
                  '• Voluntary Exit: Workshop Partners may terminate their participation at any time by clearing pending bookings, fulfilling ongoing warranty obligations, and submitting an account closure ticket.',
            ),

            // Section 9
            _buildSection(
              number: '9',
              title: 'Partner Support & Grievance Redressal',
              content:
                  'If you have questions regarding this Agreement, payment settlement queries, dispute claims, or account status, please reach out to our dedicated Partner Support Desk:\n\n'
                  '• Partner Support: In-App "Raise Ticket" under Help & Support\n'
                  '• Partner Email: partners@urbanservice.co.in\n'
                  '• Support Helpline: +91 9387443334\n'
                  '• Corporate Address: Urban Service Technologies India Pvt. Ltd., Auto Hub Tech Park, India.',
            ),

            const SizedBox(height: 30),

            // Acceptance Confirmation
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_outlined, color: Color(0xFF059669), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'By operating your workshop on Urban Service, you acknowledge and agree to abide by these Partner Terms & Conditions.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
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
