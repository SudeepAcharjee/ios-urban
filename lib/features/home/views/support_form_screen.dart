import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/booking_provider.dart';

class SupportFormScreen extends ConsumerStatefulWidget {
  const SupportFormScreen({super.key});

  @override
  ConsumerState<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends ConsumerState<SupportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _issueController = TextEditingController();
  bool _isSubmitting = false;
  Map<String, dynamic>? _selectedBooking;

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    const backgroundColor = Colors.white;
    const textPrimary = Color(0xFF111827);
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
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
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'My Issues',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your issue',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'We will get back to you as soon as possible.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 35),
              
              _buildTextField('Name', 'Enter your name', _nameController),
              const SizedBox(height: 25),
              _buildTextField('Subject', 'What is this about?', _subjectController),
              const SizedBox(height: 25),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Booking (Optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 10),
                  bookingsAsync.when(
                    data: (bookings) {
                      if (bookings.isEmpty) {
                        return const Text('No past bookings available.', style: TextStyle(color: Colors.grey));
                      }
                      
                      return PopupMenuButton<Map<String, dynamic>?>(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        position: PopupMenuPosition.under,
                        onSelected: (value) {
                          setState(() {
                            if (value != null && value['id'] == 'general') {
                              _selectedBooking = null;
                            } else {
                              _selectedBooking = value;
                            }
                          });
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: {'id': 'general'},
                            child: Text('General Query (No Booking)'),
                          ),
                          ...bookings.map((b) {
                            final title = b['title'] ?? 'Service';
                            final date = b['date'] ?? '';
                            return PopupMenuItem(
                              value: b,
                              child: Text(
                                '$title ($date)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedBooking == null 
                                      ? 'General Query (No Booking)'
                                      : '${_selectedBooking!['title'] ?? 'Service'} (${_selectedBooking!['date'] ?? ''})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _selectedBooking == null ? Colors.grey.shade600 : const Color(0xFF111827),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => const Text('Error loading bookings', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              
              _buildTextArea('Issue', 'Describe your issue in detail...', _issueController),
              
              const SizedBox(height: 50),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isSubmitting = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance.collection('support').add({
                          'userId': user?.uid,
                          'name': _nameController.text.trim(),
                          'subject': _subjectController.text.trim(),
                          'issue': _issueController.text.trim(),
                          'bookingId': _selectedBooking != null ? (_selectedBooking!['bookingId'] ?? _selectedBooking!['id']) : null,
                          'bookingName': _selectedBooking != null ? (_selectedBooking!['title'] ?? 'Service') : null,
                          'status': 'Open',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        
                        if (mounted) {
                          toastification.show(
                            context: context,
                            type: ToastificationType.success,
                            style: ToastificationStyle.flatColored,
                            title: const Text('Issue Submitted Successfully'),
                            description: const Text('Our team will review it and get back to you.'),
                            autoCloseDuration: const Duration(seconds: 4),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          toastification.show(
                            context: context,
                            type: ToastificationType.error,
                            style: ToastificationStyle.flatColored,
                            title: const Text('Error Submitting Issue'),
                            description: Text(e.toString()),
                            autoCloseDuration: const Duration(seconds: 4),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSubmitting = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting 
                      ? const SizedBox(
                          width: 24, 
                          height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          validator: (value) => value == null || value.isEmpty ? 'This field is required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2029C5), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: 5,
          validator: (value) => value == null || value.isEmpty ? 'Please describe your issue' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2029C5), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }
}
