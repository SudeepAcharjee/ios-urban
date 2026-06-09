import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'faq_screen.dart';
import 'chat_screen.dart';
import 'support_form_screen.dart';
import '../../../core/utils/custom_toast.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF111827)),
          ),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How can we help you?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),

              // Items Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                    _buildSupportItem(
                      icon: Icons.help_outline_rounded,
                      title: 'FAQs',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FAQScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSupportItem(
                      icon: Icons.assignment_outlined,
                      title: 'My Issues',
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportFormScreen()));
                      },
                    ),
                    _buildDivider(),
                    _buildSupportItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Chat with Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
                              return ChatScreen(
                                providerName: 'Urban Services',
                                providerRole: 'Direct',
                                bookingId: 'messages/$userId',
                                avatarType: 'text',
                                avatarText: 'US',
                                avatarBgColor: const Color(0xFF2029C5),
                              );



                            },
                          ),

                        );
                      },
                    ),
                    _buildDivider(),
                    _buildSupportItem(
                      icon: Icons.phone_outlined,
                      title: 'Call Us',
                      subtitle: '+91 9387443334',
                      onTap: () async {
                        final Uri launchUri = Uri(
                          scheme: 'tel',
                          path: '+919387443334',
                        );
                        try {
                          await launchUrl(launchUri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            CustomToast.error(context, 'Could not open phone dialer');
                          }
                        }
                      },
                    ),
                    _buildDivider(),
                    _buildSupportItem(
                      icon: Icons.mail_outline_rounded,
                      title: 'Email Us',
                      subtitle: 'support@urbanservice.co.in',
                      onTap: () async {
                        final Uri launchUri = Uri(
                          scheme: 'mailto',
                          path: 'support@urbanservice.co.in',
                          query: 'subject=Support Inquiry',
                        );
                        try {
                          await launchUrl(launchUri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (context.mounted) {
                            CustomToast.error(context, 'Could not open email client');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      )
    );
  }

  Widget _buildSupportItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
    );
  }
}
