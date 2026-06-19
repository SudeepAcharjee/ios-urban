import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../viewmodels/booking_provider.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const MessagesListScreen({super.key, this.showBackButton = true});

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();

  late List<ChatSummary> _chats;
  final Map<String, Map<String, dynamic>> _dynamicChatData = {};
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

  @override
  void initState() {
    super.initState();
    _chats = [
      ChatSummary(
        id: 'messages/$_currentUserId',
        name: 'Urban Services',
        role: 'Official Support',
        lastMessage: 'Tap to chat',
        time: '',
        unreadCount: 0,
        avatarType: 'icon',
        avatarIcon: Icons.headset_mic_rounded,
        avatarBgColor: const Color(0xFF2029C5),
        category: 'Support',
        isVerified: true,
      ),
      ChatSummary(
        id: 'offers/$_currentUserId',
        name: 'Special Offers',
        role: 'Promo',
        lastMessage: '',
        time: '',
        unreadCount: 0,
        avatarType: 'icon',
        avatarIcon: Icons.percent_outlined,
        avatarBgColor: const Color(0xFF0EA5E9),
        category: 'Promotions',
      ),
    ];
    _listenToChats();
  }

  void _listenToChats() {
    for (int i = 0; i < _chats.length; i++) {
      final sub = _dbRef.child(_chats[i].id).limitToLast(50).onValue.listen((event) {
        if (event.snapshot.value != null) {
          final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
          if (data.isNotEmpty) {
            int unread = 0;
            dynamic lastMsgData;
            int maxTimestamp = 0;

            data.forEach((key, value) {
              final timestamp = value['timestamp'] ?? 0;
              if (timestamp > maxTimestamp) {
                maxTimestamp = timestamp;
                lastMsgData = value;
              }
              if (value['senderId'] != null && value['senderId'] != _currentUserId && value['isRead'] != true) {
                unread++;
              }
            });
            
            final String text = lastMsgData?['text'] ?? '';
            final int timestamp = lastMsgData?['timestamp'] ?? 0;
            
            if (mounted) {
              setState(() {
                _chats[i] = _chats[i].copyWith(
                  lastMessage: text,
                  time: _formatTimestamp(timestamp),
                  timestamp: timestamp,
                  unreadCount: unread,
                );
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _chats[i] = _chats[i].copyWith(
                lastMessage: _chats[i].category == 'Promotions' ? '' : 'Tap to chat',
                time: '',
                unreadCount: 0,
              );
            });
          }
        }
      });
      _subscriptions.add(sub);
    }
  }

  void _listenToDynamicChats(List<ChatSummary> chats) {
    for (var chat in chats) {
      if (_activeListeners.contains(chat.id)) continue;
      
      _activeListeners.add(chat.id);
      final sub = _dbRef.child(chat.id).limitToLast(50).onValue.listen((event) {
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
                if (value['senderId'] != null && value['senderId'] != _currentUserId && value['isRead'] != true) {
                  unread++;
                }
              }
            });
            
            if (lastMsgData != null && mounted) {
              final String text = lastMsgData['text'] ?? (lastMsgData['imageUrl'] != null ? 'Sent an image' : '');
              final int timestamp = lastMsgData['timestamp'] ?? 0;
              
              setState(() {
                _dynamicChatData[chat.id] = {
                  'text': text,
                  'timestamp': timestamp,
                  'time': _formatTimestamp(timestamp),
                  'unreadCount': unread,
                };
                
                final staticIndex = _chats.indexWhere((c) => c.id == chat.id);
                if (staticIndex != -1) {
                  _chats[staticIndex] = _chats[staticIndex].copyWith(
                    lastMessage: text,
                    time: _formatTimestamp(timestamp),
                    timestamp: timestamp,
                    unreadCount: unread,
                  );
                }
              });
            }
          }
        }
      });
      _subscriptions.add(sub);
    }
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

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: widget.showBackButton ? IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF1E293B)),
          ),
        ) : null,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          final dynamicChats = List<ChatSummary>.from(_chats);
          
          // Deduplicate by worker, only keeping workers with at least one active (non-completed/non-cancelled) booking
          final Map<String, Map<String, dynamic>> uniqueWorkerBookings = {};
          final Map<String, List<Map<String, dynamic>>> bookingsByWorker = {};
          
          for (var booking in bookings) {
            final workerId = booking['workerId'] as String?;
            final workerName = booking['workerName'] as String?;
            if (workerId != null || workerName != null) {
              final String key = workerId ?? workerName!;
              bookingsByWorker.putIfAbsent(key, () => []).add(booking);
            }
          }

          bookingsByWorker.forEach((key, workerBookings) {
            Map<String, dynamic>? activeBooking;
            for (var booking in workerBookings) {
              final String status = (booking['status'] as String? ?? '').toUpperCase();
              if (status != 'COMPLETED' && 
                  status != 'JOB COMPLETED' && 
                  status != 'CANCELLED') {
                activeBooking = booking;
                break;
              }
            }
            if (activeBooking != null) {
              uniqueWorkerBookings[key] = activeBooking;
            }
          });

          for (var booking in uniqueWorkerBookings.values) {
            final workerName = booking['workerName'] as String? ?? 'Provider';
            final workerId = booking['workerId'] as String?;
            final workerImage = booking['workerImage'] as String?;
            final bookingId = booking['id'] as String? ?? 'unknown';

            String chatId = 'bookings/$bookingId';
            if (workerId != null && workerId.isNotEmpty) {
              final List<String> ids = [_currentUserId, workerId]..sort();
              chatId = 'direct_chats/${ids[0]}_${ids[1]}';
            }

            if (!dynamicChats.any((c) => c.id == chatId)) {
              dynamicChats.add(ChatSummary(
                id: chatId,
                name: workerName,
                role: 'Service Provider',
                lastMessage: 'Tap to chat',
                time: '',
                unreadCount: 0,
                avatarType: 'icon',
                avatarIcon: Icons.person,
                avatarBgColor: const Color(0xFF10B981),
                category: 'Provider',
                imageUrl: workerImage,
                workerId: workerId,
              ));
            }
          }

          // Use addPostFrameCallback to avoid setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _listenToDynamicChats(dynamicChats);
              // Also listen to any other bookings not in the unique list to catch notifications/unread counts
              for (var booking in bookings) {
                final bId = booking['id'] as String?;
                final wId = booking['workerId'] as String?;
                if (wId != null) {
                  final List<String> ids = [_currentUserId, wId]..sort();
                  final p2pId = 'direct_chats/${ids[0]}_${ids[1]}';
                  _listenToDynamicChats([ChatSummary(id: p2pId, name: '', role: '', lastMessage: '', time: '', unreadCount: 0, avatarType: '', avatarBgColor: Colors.transparent, category: '')]);
                } else if (bId != null) {
                  _listenToDynamicChats([ChatSummary(id: 'bookings/$bId', name: '', role: '', lastMessage: '', time: '', unreadCount: 0, avatarType: '', avatarBgColor: Colors.transparent, category: '')]);
                }
              }
            }
          });

          // Support chat always at top, then others sorted by timestamp
          final supportChats = dynamicChats.where((c) => c.category == 'Support').toList();
          final otherChats = dynamicChats.where((c) => c.category != 'Support').toList()
            ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

          final sortedChats = [...supportChats, ...otherChats];

          if (sortedChats.isEmpty) {
            return const Center(child: Text('No messages found'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: sortedChats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final chat = sortedChats[index];
              return _buildChatTile(context, chat);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2029C5))),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ChatSummary chat) {
    final dynamicData = _dynamicChatData[chat.id];
    final displayMsg = dynamicData?['text'] ?? chat.lastMessage;
    final displayTime = dynamicData?['time'] ?? chat.time;
    final unreadCount = dynamicData?['unreadCount'] ?? chat.unreadCount;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              providerName: chat.name,
              providerRole: chat.role,
              bookingId: chat.id,
              isReadOnly: chat.category == 'Promotions',
              avatarType: chat.avatarType,
              avatarText: chat.avatarText,
              avatarIcon: chat.avatarIcon,
              avatarBgColor: chat.avatarBgColor,
              imageUrl: chat.imageUrl,
              recipientId: chat.workerId,
              recipientRole: chat.category == 'Provider' ? 'worker' : null,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            chat.category == 'Provider' && chat.workerId != null && chat.workerId!.isNotEmpty
                ? StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('workers').doc(chat.workerId).snapshots(),
                    builder: (context, snapshot) {
                      String? displayImg = chat.imageUrl;
                      if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                        final workerData = snapshot.data!.data() as Map<String, dynamic>?;
                        if (workerData != null) {
                          if (workerData['profilePic'] != null && workerData['profilePic'].toString().isNotEmpty) {
                            displayImg = workerData['profilePic'];
                          } else if (workerData['imageUrl'] != null && workerData['imageUrl'].toString().isNotEmpty) {
                            displayImg = workerData['imageUrl'];
                          }
                        }
                      }
                      return Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: chat.avatarBgColor,
                          borderRadius: BorderRadius.circular(16),
                          image: displayImg != null && displayImg.isNotEmpty ? DecorationImage(
                            image: NetworkImage(displayImg),
                            fit: BoxFit.cover,
                          ) : null,
                        ),
                        child: (displayImg == null || displayImg.isEmpty) ? Center(
                          child: Icon(chat.avatarIcon, color: Colors.white, size: 28),
                        ) : null,
                      );
                    },
                  )
                : Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: chat.avatarBgColor,
                      borderRadius: BorderRadius.circular(16),
                      image: chat.imageUrl != null && chat.imageUrl!.isNotEmpty ? DecorationImage(
                        image: NetworkImage(chat.imageUrl!),
                        fit: BoxFit.cover,
                      ) : null,
                    ),
                    child: (chat.imageUrl == null || chat.imageUrl!.isEmpty) ? Center(
                      child: chat.avatarType == 'text'
                          ? Text(
                              chat.avatarText ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Icon(chat.avatarIcon, color: Colors.white, size: 28),
                    ) : null,
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      if (unreadCount > 0) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          chat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (chat.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  if (displayMsg.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      displayMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: unreadCount > 0 ? const Color(0xFF1E293B) : Colors.grey.shade500,
                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade800, size: 20),
          ],
        ),
      ),
    );
  }
}

class ChatSummary {
  final String id;
  final String name;
  final String role;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String avatarType;
  final String? avatarText;
  final IconData? avatarIcon;
  final Color avatarBgColor;
  final String category;
  final int? timestamp;
  final String? imageUrl;
  final bool isVerified;
  final String? workerId;

  ChatSummary({
    required this.id,
    required this.name,
    required this.role,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.avatarType,
    this.avatarText,
    this.avatarIcon,
    required this.avatarBgColor,
    required this.category,
    this.timestamp,
    this.imageUrl,
    this.isVerified = false,
    this.workerId,
  });

  ChatSummary copyWith({
    String? lastMessage,
    String? time,
    int? timestamp,
    String? imageUrl,
    int? unreadCount,
    bool? isVerified,
    String? workerId,
  }) {
    return ChatSummary(
      id: id,
      name: name,
      role: role,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarType: avatarType,
      avatarText: avatarText,
      avatarIcon: avatarIcon,
      avatarBgColor: avatarBgColor,
      category: category,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isVerified: isVerified ?? this.isVerified,
      workerId: workerId ?? this.workerId,
    );
  }
}
