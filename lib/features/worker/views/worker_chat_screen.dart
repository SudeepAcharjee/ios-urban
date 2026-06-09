import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../home/views/chat_screen.dart';
import '../viewmodels/worker_provider.dart';
import 'worker_disabled_overlay.dart';


class WorkerChatScreen extends ConsumerStatefulWidget {
  const WorkerChatScreen({super.key});

  @override
  ConsumerState<WorkerChatScreen> createState() => _WorkerChatScreenState();
}

class _WorkerChatScreenState extends ConsumerState<WorkerChatScreen> {
  final String _workerId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();

  // Stores real-time last message data per bookingId
  final Map<String, Map<String, dynamic>> _lastMessages = {};
  
  // Support chat data
  Map<String, dynamic>? _supportLastMessage;

  @override
  void initState() {
    super.initState();
    _listenToSupportChat();
  }

  void _listenToSupportChat() {
    final sub = _dbRef.child('support_chats/$_workerId').limitToLast(20).onValue.listen((event) {
      if (mounted) {
        final Map<dynamic, dynamic>? messages = event.snapshot.value as Map<dynamic, dynamic>?;
        if (messages != null) {
          Map<dynamic, dynamic>? lastMsgData;
          int maxTimestamp = 0;
          int unread = 0;

          messages.forEach((key, value) {
            final timestamp = value['timestamp'] ?? 0;
            if (timestamp > maxTimestamp) {
              maxTimestamp = timestamp;
              lastMsgData = value;
            }
            if (value['senderId'] != null && value['senderId'] == 'admin' && value['isRead'] != true) {
              unread++;
            }
          });

          if (lastMsgData != null) {
            setState(() {
              _supportLastMessage = {
                'text': lastMsgData?['text'] ?? '',
                'time': _formatTimestamp(maxTimestamp),
                'timestamp': maxTimestamp,
                'isFromAdmin': true,
                'unreadCount': unread,
              };
            });
          }
        }
      }
    });
    _subscriptions.add(sub);
  }
  final Set<String> _activeListeners = {};
  final List<StreamSubscription> _subscriptions = [];

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _activeListeners.clear();
    super.dispose();
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return '';
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));

    if (date.isAfter(today)) {
      return DateFormat('hh:mm a').format(date);
    } else if (date.isAfter(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  void _listenToBookingChat(String chatPath) {
    if (_activeListeners.contains(chatPath)) return;
    _activeListeners.add(chatPath);

    final sub = _dbRef.child(chatPath).limitToLast(50).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final rawData = event.snapshot.value;
        if (rawData is Map) {
          final Map<dynamic, dynamic> data = rawData;
          int unread = 0;
          dynamic lastMsgData;
          int maxTimestamp = 0;

          data.forEach((key, value) {
            if (value is Map) {
              final timestamp = value['timestamp'] ?? 0;
              if (timestamp is int && timestamp > maxTimestamp) {
                maxTimestamp = timestamp;
                lastMsgData = value;
              }
              if (value['senderId'] != null && 
                  value['senderId'] != _workerId && 
                  value['isRead'] != true) {
                unread++;
              }
            }
          });

          if (lastMsgData != null && mounted) {
            final String text = lastMsgData['text'] ?? (lastMsgData['imageUrl'] != null ? 'Sent an image' : '');
            final int timestamp = lastMsgData['timestamp'] ?? 0;

            setState(() {
              _lastMessages[chatPath] = {
                'text': text,
                'timestamp': timestamp,
                'time': _formatTimestamp(timestamp),
                'unreadCount': unread,
                'isFromUser': lastMsgData['senderId'] != _workerId,
              };
            });
          }
        }
      }
    }, onError: (err) {
      debugPrint('RTDB Error for $chatPath: $err');
    });
    _subscriptions.add(sub);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final assignedTasksAsync = ref.watch(workerAssignedTasksProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: assignedTasksAsync.when(
        data: (tasks) {
          final Map<String, Map<String, dynamic>> uniqueUserTasks = {};
          for (var task in tasks) {
            final userId = task['userId'] as String?;
            if (userId != null) {
              if (!uniqueUserTasks.containsKey(userId)) {
                uniqueUserTasks[userId] = task;
              }
            }
          }
          final List<Map<String, dynamic>> displayTasks = uniqueUserTasks.values.toList();

          // Initialize listeners for ALL tasks outside of build return
          for (var task in tasks) {
            final bId = task['id'] as String?;
            final uId = task['userId'] as String?;
            if (uId != null) {
              final List<String> ids = [_workerId, uId]..sort();
              final p2pId = 'direct_chats/${ids[0]}_${ids[1]}';
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _listenToBookingChat(p2pId); // Overloaded path
              });
            } else if (bId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _listenToBookingChat(bId);
              });
            }
          }

          return Column(
            children: [
              // 🎧 Fixed Support Chat at Top
              _buildSupportTile(context, primaryColor),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              
              Expanded(
                child: displayTasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: displayTasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final task = displayTasks[index];
              final bookingId = task['id'] as String? ?? '';
              final userId = task['userId'] as String?;
              
              String chatId = 'bookings/$bookingId';
              if (userId != null && userId.isNotEmpty) {
                final List<String> ids = [_workerId, userId]..sort();
                chatId = 'direct_chats/${ids[0]}_${ids[1]}';
              }

              final lastMsgData = _lastMessages[chatId];
              final lastText = lastMsgData?['text'] as String?;
              final lastTime = lastMsgData?['time'] as String? ?? '';
              final unreadCount = lastMsgData?['unreadCount'] as int? ?? 0;

              return FutureBuilder<Map<String, dynamic>?>(
                future: userId != null
                    ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get()
                        .then((doc) => doc.data())
                    : Future.value(null),
                builder: (context, snapshot) {
                  // Show skeleton tile while resolving user name
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonTile();
                  }
                  final userData = snapshot.data;
                  final userName = userData?['name'] ?? task['userName'] ?? 'Customer';
                  final resolvedImage = userData?['profilePic'] ?? task['userImage'];
                  final serviceName = task['serviceName'] as String? ?? 'Service';

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            providerName: userName,
                            providerRole: serviceName,
                            bookingId: chatId,
                            isReadOnly: false,
                            avatarType: resolvedImage != null ? 'image' : 'icon',
                            avatarIcon: Icons.person,
                            avatarBgColor: primaryColor,
                            imageUrl: resolvedImage,
                            recipientId: userId,
                            recipientRole: 'user',
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(16),
                              image: resolvedImage != null
                                  ? DecorationImage(
                                      image: NetworkImage(resolvedImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: resolvedImage == null
                                ? const Center(
                                    child: Icon(Icons.person, color: Colors.white, size: 26),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (lastTime.isNotEmpty)
                                      Text(
                                        lastTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: unreadCount > 0 ? const Color(0xFF2029C5) : Colors.grey.shade400,
                                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                  ],
                                ),
                                if (lastText != null && lastText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lastText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: unreadCount > 0 ? const Color(0xFF1E293B) : Colors.grey.shade500,
                                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (unreadCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2029C5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            unreadCount.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
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
                },
              );
            },
          ),
        ),
      ],
    );
  },
          loading: () => _buildSkeleton(),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      const PendingCashPaymentOverlay(),
    ]);
  }


  // -- UI Helpers ------------------------------------------
  Widget _buildSupportTile(BuildContext context, Color primaryColor) {
    final lastText = _supportLastMessage?['text'] as String? ?? 'Contact support for help';
    final lastTime = _supportLastMessage?['time'] as String? ?? '';
    final unreadCount = _supportLastMessage?['unreadCount'] as int? ?? 0;

    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              providerName: 'Urban Services',
              providerRole: 'Official Support',
              bookingId: 'support_chats/$_workerId',
              avatarType: 'icon',
              avatarIcon: Icons.headset_mic_rounded,
              avatarBgColor: primaryColor,
            ),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.headset_mic_rounded, color: primaryColor, size: 28),
      ),
      title: const Row(
        children: [
          Text(
            'Urban Services',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
          ),
          SizedBox(width: 6),
          Icon(Icons.verified_rounded, color: Colors.blue, size: 16),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          lastText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0 ? const Color(0xFF1E293B) : Colors.grey.shade500,
            fontSize: 13,
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            lastTime,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFFE2E8F0)),
          SizedBox(height: 16),
          Text(
            'No customer chats yet',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Customer conversations will appear here',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -- Skeleton helpers ------------------------------------------
  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (_, __) => _buildSkeletonTile(),
    );
  }

  Widget _buildSkeletonTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _shimmer(width: 55, height: 55, radius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(width: 140, height: 14, radius: 6),
                const SizedBox(height: 8),
                _shimmer(width: double.infinity, height: 11, radius: 6),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _shimmer(width: 36, height: 11, radius: 6),
        ],
      ),
    );
  }

  Widget _shimmer({required double width, required double height, required double radius}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF1F5),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      onEnd: () => setState(() {}),
    );
  }
}