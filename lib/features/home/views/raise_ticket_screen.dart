import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/utils/custom_toast.dart';

class RaiseTicketScreen extends StatefulWidget {
  final String? initialBookingId;
  final String? initialBookingTitle;
  final String? initialCategory;

  const RaiseTicketScreen({
    super.key,
    this.initialBookingId,
    this.initialBookingTitle,
    this.initialCategory,
  });

  @override
  State<RaiseTicketScreen> createState() => _RaiseTicketScreenState();
}

class _RaiseTicketScreenState extends State<RaiseTicketScreen> with SingleTickerProviderStateMixin {
  static const primaryColor = Color(0xFF2029C5);
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedCategory = 'Booking / Service Issue';
  String _selectedPriority = 'Medium';
  String? _selectedBookingId;
  String? _selectedBookingTitle;

  final List<XFile> _selectedAttachments = [];
  bool _isSubmitting = false;
  String _submittingStatus = '';
  String _userRole = 'Customer';
  bool _isLoadingUserData = true;

  final List<String> _categories = [
    'Booking / Service Issue',
    'Payment & Billing',
    'Workshop & Partner Issue',
    'Service Delay / Rescheduling',
    'Quality & Vehicle Damage',
    'Account & Verification',
    'App / Technical Glitch',
    'General Inquiry / Other',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialBookingId != null) {
      _selectedBookingId = widget.initialBookingId;
      _selectedBookingTitle = widget.initialBookingTitle ?? 'Booking #${widget.initialBookingId}';
    }
    if (widget.initialCategory != null && _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadCurrentUserInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingUserData = false);
      return;
    }

    _emailController.text = user.email ?? '';

    try {
      // 1. Check shop collection
      final shopDoc = await FirebaseFirestore.instance.collection('shops').doc(user.uid).get();
      if (shopDoc.exists && shopDoc.data() != null) {
        final sData = shopDoc.data()!;
        _userRole = 'Shop Owner';
        _nameController.text = (sData['shopName'] ?? sData['ownerName'] ?? sData['name'] ?? user.displayName ?? '').toString();
        _phoneController.text = (sData['phone'] ?? sData['phoneNumber'] ?? user.phoneNumber ?? '').toString();
        if (mounted) setState(() => _isLoadingUserData = false);
        return;
      }

      // 2. Check worker collection
      final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(user.uid).get();
      if (workerDoc.exists && workerDoc.data() != null) {
        final wData = workerDoc.data()!;
        _userRole = 'Worker';
        _nameController.text = (wData['name'] ?? wData['fullName'] ?? user.displayName ?? '').toString();
        _phoneController.text = (wData['phone'] ?? wData['phoneNumber'] ?? user.phoneNumber ?? '').toString();
        if (mounted) setState(() => _isLoadingUserData = false);
        return;
      }

      // 3. Fallback to users collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final uData = userDoc.data()!;
        _userRole = 'Customer';
        _nameController.text = (uData['name'] ?? uData['fullName'] ?? user.displayName ?? '').toString();
        _phoneController.text = (uData['phone'] ?? uData['phoneNumber'] ?? user.phoneNumber ?? '').toString();
        if (uData['email'] != null && _emailController.text.isEmpty) {
          _emailController.text = uData['email'].toString();
        }
      } else {
        _nameController.text = user.displayName ?? 'Customer';
        _phoneController.text = user.phoneNumber ?? '';
      }
    } catch (e) {
      debugPrint('Error loading user info for ticket: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _pickAttachment(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    if (source == ImageSource.camera) {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        setState(() => _selectedAttachments.add(photo));
      }
    } else {
      final List<XFile> photos = await picker.pickMultiImage(imageQuality: 85);
      if (photos.isNotEmpty) {
        setState(() => _selectedAttachments.addAll(photos));
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      CustomToast.error(context, 'Please login to raise a support ticket.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submittingStatus = 'Creating ticket...';
    });

    try {
      final List<String> uploadedUrls = [];
      if (_selectedAttachments.isNotEmpty) {
        for (int i = 0; i < _selectedAttachments.length; i++) {
          setState(() {
            _submittingStatus = 'Uploading attachment (${i + 1}/${_selectedAttachments.length})...';
          });
          final url = await CloudinaryService.uploadImage(
            File(_selectedAttachments[i].path),
            folder: 'support_tickets',
          );
          if (url != null && url.isNotEmpty) {
            uploadedUrls.add(url);
          }
        }
      }

      setState(() => _submittingStatus = 'Saving support ticket...');

      final String randomSuffix = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
      final String ticketId = 'TICK-$randomSuffix';

      final Map<String, dynamic> ticketData = {
        'ticketId': ticketId,
        'userId': user.uid,
        'userName': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'User',
        'userEmail': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : (user.email ?? ''),
        'userPhone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : '',
        'userRole': _userRole,
        'subject': _subjectController.text.trim(),
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'description': _descriptionController.text.trim(),
        'issue': _descriptionController.text.trim(), // backward compatibility with admin panel
        'bookingId': _selectedBookingId,
        'bookingName': _selectedBookingTitle,
        'attachmentUrls': uploadedUrls,
        'attachments': uploadedUrls, // backward compatibility
        'status': 'Open',
        'adminNotes': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('support').add(ticketData);

      if (mounted) {
        _showSuccessDialog(ticketId);
        _subjectController.clear();
        _descriptionController.clear();
        _selectedAttachments.clear();
        _selectedBookingId = null;
        _selectedBookingTitle = null;
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to raise ticket: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog(String ticketId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ticket Raised Successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Ticket Ref: #$ticketId',
                style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your request has been forwarded to the admin support team. We will review your issue and update the ticket status soon.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _tabController.animateTo(1); // Switch to My Tickets tab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('View My Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingPickerModal() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Link a Booking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the booking related to this issue (optional)',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // "No Booking / General Query" option
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _selectedBookingId == null ? primaryColor : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                tileColor: _selectedBookingId == null ? primaryColor.withOpacity(0.06) : Colors.transparent,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: Color(0xFF64748B), size: 20),
                ),
                title: const Text('General Inquiry (No Booking)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Issue unrelated to any specific order', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                onTap: () {
                  setState(() {
                    _selectedBookingId = null;
                    _selectedBookingTitle = null;
                  });
                  Navigator.pop(ctx);
                },
              ),

              const SizedBox(height: 8),

              // Recent bookings list
              Flexible(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where(
                        _userRole == 'Shop Owner' ? 'shopId' : (_userRole == 'Worker' ? 'workerId' : 'userId'),
                        isEqualTo: user.uid,
                      )
                      .limit(20)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No recent bookings found.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final bDoc = docs[index];
                        final data = bDoc.data();
                        final id = bDoc.id;
                        final title = (data['title'] ?? data['serviceName'] ?? 'Service').toString();
                        final status = (data['status'] ?? 'Pending').toString();
                        final date = (data['date'] ?? data['bookingDate'] ?? '').toString();
                        final isSelected = _selectedBookingId == id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? primaryColor : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          tileColor: isSelected ? primaryColor.withOpacity(0.06) : Colors.transparent,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.build_circle_outlined, color: primaryColor, size: 20),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'ID: #${id.length > 8 ? id.substring(id.length - 8) : id} • $status ${date.isNotEmpty ? '• $date' : ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: primaryColor) : null,
                          onTap: () {
                            setState(() {
                              _selectedBookingId = id;
                              _selectedBookingTitle = title;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF0F172A)),
          ),
        ),
        title: const Text(
          'Support & Tickets',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              labelColor: primaryColor,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_task_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Raise Ticket'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('My Tickets'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRaiseTicketForm(),
          _buildMyTicketsList(),
        ],
      ),
    );
  }

  Widget _buildRaiseTicketForm() {
    if (_isLoadingUserData) {
      return const Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User role & info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : 'Account User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Text(
                                _userRole,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _emailController.text.isNotEmpty ? _emailController.text : (_phoneController.text.isNotEmpty ? _phoneController.text : 'Verified User'),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Category Picker
            const Text(
              'Issue Category',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedCategory,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Priority Level Selector
            const Text(
              'Priority Level',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Row(
              children: _priorities.map((p) {
                final isSelected = _selectedPriority == p;
                Color chipColor;
                Color chipBg;
                if (p == 'Urgent') {
                  chipColor = Colors.red.shade700;
                  chipBg = Colors.red.shade50;
                } else if (p == 'High') {
                  chipColor = const Color(0xFFEA580C);
                  chipBg = const Color(0xFFFFF7ED);
                } else if (p == 'Medium') {
                  chipColor = const Color(0xFF2563EB);
                  chipBg = const Color(0xFFEFF6FF);
                } else {
                  chipColor = const Color(0xFF059669);
                  chipBg = const Color(0xFFECFDF5);
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = p),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? chipBg : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? chipColor : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? chipColor : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Link to Booking (Optional)
            const Text(
              'Related Booking (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showBookingPickerModal,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedBookingId != null ? Icons.link_rounded : Icons.link_off_rounded,
                      color: _selectedBookingId != null ? primaryColor : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedBookingId != null
                            ? '${_selectedBookingTitle ?? 'Booking'} (#${_selectedBookingId!.length > 8 ? _selectedBookingId!.substring(_selectedBookingId!.length - 8) : _selectedBookingId})'
                            : 'Tap to link a booking (General Query)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _selectedBookingId != null ? FontWeight.bold : FontWeight.w500,
                          color: _selectedBookingId != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Subject / Title
            const Text(
              'Subject / Issue Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectController,
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a ticket subject' : null,
              decoration: InputDecoration(
                hintText: 'e.g., Payment charged but booking unconfirmed',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Detailed Description
            const Text(
              'Detailed Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              validator: (v) => v == null || v.trim().length < 10 ? 'Please describe the issue in at least 10 characters' : null,
              decoration: InputDecoration(
                hintText: 'Please provide full details of what happened, time of incident, transaction ID or specific concern...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Attachments (Screenshots / Proof)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Screenshots / Attachments (Optional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                if (_selectedAttachments.isNotEmpty)
                  Text(
                    '${_selectedAttachments.length} selected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _pickAttachment(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _pickAttachment(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedAttachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedAttachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, index) {
                    final file = _selectedAttachments[index];
                    return Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            image: DecorationImage(
                              image: FileImage(File(file.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (!_isSubmitting)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedAttachments.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black87,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Submit Button
            if (_isSubmitting && _submittingStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
                    const SizedBox(width: 10),
                    Text(
                      _submittingStatus,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTicket,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit Ticket to Admin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view your tickets.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading tickets: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_turned_in_outlined, size: 48, color: primaryColor),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Support Tickets Yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You haven\'t raised any support tickets yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Raise a Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort in memory by createdAt descending
        final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
        sortedDocs.sort((a, b) {
          final aTs = a.data()['createdAt'];
          final bTs = b.data()['createdAt'];
          if (aTs is Timestamp && bTs is Timestamp) {
            return bTs.compareTo(aTs);
          }
          return 0;
        });

        return ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data();
            final ticketId = (data['ticketId'] ?? doc.id).toString();
            final subject = (data['subject'] ?? 'Support Inquiry').toString();
            final category = (data['category'] ?? 'General').toString();
            final status = (data['status'] ?? 'Open').toString();
            final priority = (data['priority'] ?? 'Medium').toString();
            final description = (data['description'] ?? data['issue'] ?? '').toString();
            final adminNotes = (data['adminNotes'] ?? data['resolution'] ?? data['response'] ?? '').toString();
            final rawAttachments = data['attachmentUrls'] ?? data['attachments'] ?? [];
            final List<String> attachments = (rawAttachments is List) ? rawAttachments.map((e) => e.toString()).toList() : [];

            String dateStr = '';
            final ts = data['createdAt'];
            if (ts is Timestamp) {
              dateStr = DateFormat('d MMM yyyy, hh:mm a').format(ts.toDate());
            }

            Color statusBg;
            Color statusColor;
            if (status.toLowerCase() == 'resolved') {
              statusBg = const Color(0xFFD1FAE5);
              statusColor = const Color(0xFF059669);
            } else if (status.toLowerCase() == 'in progress') {
              statusBg = const Color(0xFFEDE9FE);
              statusColor = const Color(0xFF7C3AED);
            } else if (status.toLowerCase() == 'closed') {
              statusBg = const Color(0xFFF1F5F9);
              statusColor = const Color(0xFF64748B);
            } else {
              statusBg = const Color(0xFFFEF3C7);
              statusColor = const Color(0xFFD97706);
            }

            return GestureDetector(
              onTap: () => _showTicketDetailsSheet(
                ticketId: ticketId,
                subject: subject,
                category: category,
                status: status,
                priority: priority,
                description: description,
                adminNotes: adminNotes,
                attachments: attachments,
                dateStr: dateStr,
                bookingId: data['bookingId']?.toString(),
                bookingTitle: data['bookingName']?.toString(),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '#$ticketId',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subject,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),
                            if (attachments.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Row(
                                children: [
                                  const Icon(Icons.attach_file_rounded, size: 14, color: Color(0xFF64748B)),
                                  Text(
                                    '${attachments.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketDetailsSheet({
    required String ticketId,
    required String subject,
    required String category,
    required String status,
    required String priority,
    required String description,
    required String adminNotes,
    required List<String> attachments,
    required String dateStr,
    String? bookingId,
    String? bookingTitle,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ticket #$ticketId',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      if (dateStr.isNotEmpty)
                        Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Priority Pills
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Status: $status',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Priority: $priority',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Linked booking
                      if (bookingId != null && bookingId.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.build_circle_outlined, color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Linked Booking: ${bookingTitle ?? 'Service'} (#$bookingId)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Subject
                      const Text(
                        'Subject',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Admin Response / Notes
                      if (adminNotes.isNotEmpty) ...[
                        const Text(
                          'Admin Response',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            adminNotes,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF065F46), height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Attachments
                      if (attachments.isNotEmpty) ...[
                        const Text(
                          'Attachments',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: attachments.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (c, i) {
                              final imgUrl = attachments[i];
                              return GestureDetector(
                                onTap: () => _showFullscreenImage(context, imgUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imgUrl,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFullscreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(ctx).padding.top + 10,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
