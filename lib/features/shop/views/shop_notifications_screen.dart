import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../core/services/sound_service.dart';
import '../../home/models/notification_model.dart';
import '../../home/views/chat_screen.dart';
import 'shop_booking_detail_screen.dart';

class ShopNotificationsScreen extends StatefulWidget {
  const ShopNotificationsScreen({super.key});

  @override
  State<ShopNotificationsScreen> createState() => _ShopNotificationsScreenState();
}

class _ShopNotificationsScreenState extends State<ShopNotificationsScreen> {
  static const primaryColor = Color(0xFF2029C5);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);

  DatabaseReference? _notificationsRef;

  @override
  void initState() {
    super.initState();
    SoundService.stopSound();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationsRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
      ).ref('notifications/${user.uid}');
    }
  }

  Future<void> _markAsRead(String notifId) async {
    if (_notificationsRef == null) return;
    try {
      await _notificationsRef!.child(notifId).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notificationsRef == null) return;
    try {
      final snapshot = await _notificationsRef!.get();
      if (snapshot.value is Map) {
        final data = snapshot.value as Map;
        final Map<String, Object?> updates = {};
        data.forEach((key, value) {
          updates['$key/isRead'] = true;
        });
        await _notificationsRef!.update(updates);
      }
      if (mounted) {
        CustomToast.success(context, 'All notifications marked as read');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to update notifications: $e');
      }
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    if (_notificationsRef == null) return;
    try {
      await _notificationsRef!.child(notifId).remove();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    if (_notificationsRef == null) return;
    try {
      await _notificationsRef!.remove();
      if (mounted) {
        CustomToast.success(context, 'All notifications cleared');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Failed to clear notifications: $e');
      }
    }
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Clear Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _clearAllNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    } else {
      return DateFormat('h:mm a').format(date);
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    _markAsRead(notification.id);

    final type = notification.type.toLowerCase();
    final bookingId = notification.bookingId;

    if (type == 'booking_request' || (bookingId != null && bookingId.isNotEmpty)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShopBookingDetailScreen(
            bookingId: bookingId ?? '',
            bookingData: const {},
          ),
        ),
      );
    } else if (type == 'chat' || type == 'message') {
      final senderId = notification.senderId;
      if (senderId != null && senderId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              providerName: 'Customer',
              providerRole: 'Customer',
              bookingId: (bookingId != null && bookingId.isNotEmpty)
                  ? (bookingId.startsWith('bookings/') ? bookingId : 'bookings/$bookingId')
                  : '',
              recipientId: senderId,
              recipientRole: 'user',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _notificationsRef == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Notifications'),
        ),
        body: const Center(child: Text('Authentication required')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textPrimary),
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
            icon: const Icon(Icons.more_vert_rounded, color: textPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'clear_all') {
                _showClearAllDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20, color: primaryColor),
                    SizedBox(width: 12),
                    Text('Mark all as read', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _notificationsRef!.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }

          final List<NotificationModel> notifications = [];
          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
            final dynamic raw = snapshot.data!.snapshot.value;
            if (raw is Map) {
              raw.forEach((key, val) {
                if (val is Map) {
                  try {
                    notifications.add(NotificationModel.fromMap(key.toString(), val));
                  } catch (e) {
                    debugPrint('Error parsing notification: $e');
                  }
                }
              });
            }
          }

          // Sort latest first
          notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade400),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Notifications Yet',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When customers book your workshop services or send you messages, you\'ll see alerts here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group by date
          final Map<String, List<NotificationModel>> grouped = {};
          for (final n in notifications) {
            final dateStr = _getDateHeader(n.timestamp);
            grouped.putIfAbsent(dateStr, () => []).add(n);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final dateHeader = grouped.keys.elementAt(index);
              final items = grouped[dateHeader]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                    child: Text(
                      dateHeader,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  ...items.map((n) => _buildNotificationCard(n)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final bool isUnread = !notification.isRead;
    final type = notification.type.toLowerCase();

    IconData iconData;
    List<Color> gradientColors;
    Color shadowColor;

    if (type.contains('booking') || type == 'booking_request') {
      iconData = Icons.receipt_long_rounded;
      gradientColors = const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
      shadowColor = const Color(0xFF2563EB);
    } else if (type.contains('chat') || type == 'message') {
      iconData = Icons.forum_rounded;
      gradientColors = const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      shadowColor = const Color(0xFF7C3AED);
    } else if (type.contains('review') || type.contains('rating')) {
      iconData = Icons.star_rounded;
      gradientColors = const [Color(0xFFF59E0B), Color(0xFFD97706)];
      shadowColor = const Color(0xFFF59E0B);
    } else if (type.contains('approved') || type.contains('verified')) {
      iconData = Icons.verified_rounded;
      gradientColors = const [Color(0xFF10B981), Color(0xFF059669)];
      shadowColor = const Color(0xFF10B981);
    } else if (type.contains('cancel') || type.contains('rejected')) {
      iconData = Icons.event_busy_rounded;
      gradientColors = const [Color(0xFFEF4444), Color(0xFFDC2626)];
      shadowColor = const Color(0xFFEF4444);
    } else {
      iconData = Icons.notifications_active_rounded;
      gradientColors = const [Color(0xFF4F46E5), Color(0xFF3730A3)];
      shadowColor = const Color(0xFF4F46E5);
    }

    return Dismissible(
      key: Key('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade500,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _deleteNotification(notification.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread ? primaryColor.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isUnread ? primaryColor.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleNotificationTap(notification),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(iconData, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(notification.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnread ? primaryColor : Colors.grey.shade500,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread ? const Color(0xFF334155) : textSecondary,
                            height: 1.35,
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Unread Dot
                  if (isUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
