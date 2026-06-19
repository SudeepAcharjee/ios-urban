import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/notification_provider.dart';
import '../models/notification_model.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking_detail_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF2029C5);
    const textPrimary = Color(0xFF111827);
    const textSecondary = Color(0xFF6B7280);
    
    final notificationsAsync = ref.watch(allNotificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: textPrimary),
            onSelected: (value) {
              if (value == 'clear_all') {
                _showClearAllDialog(context, ref);
              } else if (value == 'mark_all_read') {
                ref.read(notificationActionsProvider).markAllAsRead();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20, color: primaryColor),
                    SizedBox(width: 10),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Notifications Yet',
                      style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll notify you when something\nnew arrives!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // Group by date
            final Map<String, List<NotificationModel>> grouped = {};
            for (var n in notifications) {
              final dateStr = _getDateHeader(n.timestamp);
              grouped.putIfAbsent(dateStr, () => []).add(n);
            }

            return RefreshIndicator(
              color: primaryColor,
              backgroundColor: Colors.white,
              onRefresh: () async {
                // ignore: unused_result
                ref.refresh(allNotificationsProvider);
                await Future.delayed(const Duration(milliseconds: 1000));
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final dateHeader = grouped.keys.elementAt(index);
                  final items = grouped[dateHeader]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(dateHeader, textSecondary),
                      ...items.map((n) => _buildNotificationCard(
                        context,
                        ref,
                        n,
                        primaryColor,
                        textPrimary,
                        textSecondary,
                      )),
                    ],
                  );
                },
              ),
            );
          },
          loading: () => _buildSkeletonList(),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 50,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('This will permanently delete all your notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationActionsProvider).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) return 'Today';
    if (notificationDate == yesterday) return 'Yesterday';
    
    // For older dates, show day, month, year
    return DateFormat('d MMMM yyyy').format(date);
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final iconInfo = _getIconInfo(notification);
    
    return GestureDetector(
      onTap: () async {
        if (!notification.isRead) {
          ref.read(notificationActionsProvider).markAsRead(notification.id);
        }

        debugPrint('Notification tapped: ID=${notification.id}, Type=${notification.type}, Title="${notification.title}", SenderID=${notification.senderId}, BookingID=${notification.bookingId}');
        final bool isAdminOrSupport = notification.type == 'support' ||
            notification.type == 'admin' ||
            notification.senderId == 'admin' ||
            notification.senderId == 'support' ||
            notification.title.toLowerCase().contains('admin') ||
            notification.title.toLowerCase().contains('support') ||
            notification.title.toLowerCase().contains('urban services');

        if (isAdminOrSupport) {
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                providerName: 'Urban Services',
                providerRole: 'Official Support',
                bookingId: 'messages/$userId',
                avatarType: 'icon',
                avatarIcon: Icons.headset_mic_rounded,
                avatarBgColor: primaryColor,
              ),
            ),
          );
        } else if (notification.type == 'chat') {
          final String providerName = notification.title.replaceAll('New Message from ', '').trim();
          final String? recipientId = notification.senderId;

          if (recipientId != null && recipientId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  providerName: providerName,
                  providerRole: 'Professional',
                  bookingId: notification.bookingId ?? 'direct_chats/$recipientId',
                  isReadOnly: false,
                  avatarType: 'icon',
                  avatarIcon: Icons.person,
                  avatarBgColor: primaryColor,
                  recipientId: recipientId,
                  recipientRole: 'worker',
                ),
              ),
            );
          }
        } else {
          final String? bookingId = notification.bookingId;
          final bool isBooking = bookingId != null &&
              bookingId.isNotEmpty &&
              !bookingId.startsWith('direct_chats') &&
              !bookingId.startsWith('support_chats') &&
              !bookingId.startsWith('messages');

          if (isBooking) {
            final String cleanedBookingId = bookingId.split('/').last;

            // Show a progress indicator/dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            );

            try {
              final doc = await FirebaseFirestore.instance
                  .collection('bookings')
                  .doc(cleanedBookingId)
                  .get();

              if (context.mounted) {
                Navigator.pop(context); // Dismiss loading dialog
              }

              if (doc.exists && doc.data() != null) {
                final bookingData = doc.data()!;
                bookingData['id'] = doc.id;

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookingDetailScreen(
                        bookingData: bookingData,
                      ),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking details not found')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context); // Dismiss loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error loading booking: $e')),
                );
              }
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconInfo.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(iconInfo.icon, color: iconInfo.color, size: 24),
            ),
            const SizedBox(width: 15),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('hh:mm a').format(notification.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '1', // Hardcoded placeholder for now as model doesn't have count
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Demo Action Buttons (if type is special)
                  if (notification.type == 'onboarding') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildActionButton('Take a tour', true),
                        const SizedBox(width: 10),
                        _buildActionButton('No, thanks!', false),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF6C63FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isPrimary ? null : Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPrimary ? Colors.white : const Color(0xFF6C63FF),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _IconInfo _getIconInfo(NotificationModel notification) {
    final type = notification.type;
    final title = notification.title.toLowerCase();
    final senderId = notification.senderId;

    if (type == 'support' ||
        type == 'admin' ||
        senderId == 'admin' ||
        senderId == 'support' ||
        title.contains('admin') ||
        title.contains('support') ||
        title.contains('urban services')) {
      return _IconInfo(Icons.headset_mic_rounded, Colors.orange);
    }

    final String? bookingId = notification.bookingId;
    final bool isBooking = bookingId != null &&
        bookingId.isNotEmpty &&
        !bookingId.startsWith('direct_chats') &&
        !bookingId.startsWith('support_chats') &&
        !bookingId.startsWith('messages');

    if (isBooking) {
      return _IconInfo(Icons.calendar_today, const Color(0xFF6C63FF));
    }

    switch (type) {
      case 'discount':
        return _IconInfo(Icons.local_offer_outlined, Colors.orange);
      case 'appointment':
      case 'booking':
        return _IconInfo(Icons.calendar_today, const Color(0xFF6C63FF));
      case 'completed':
        return _IconInfo(Icons.event_available, Colors.green);
      case 'cancelled':
        return _IconInfo(Icons.event_busy, Colors.red);
      case 'onboarding':
        return _IconInfo(Icons.medical_services_outlined, const Color(0xFF6C63FF));
      case 'chat':
        return _IconInfo(Icons.chat_bubble_outline_rounded, Colors.blue);
      default:
        return _IconInfo(Icons.notifications_none_rounded, Colors.blue);
    }
  }
}

class _IconInfo {
  final IconData icon;
  final Color color;
  _IconInfo(this.icon, this.color);
}
