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
        lastMessage: 'Tap to chat',
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

  int _extractTimestamp(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  void _listenToChats() {
    for (int i = 0; i < _chats.length; i++) {
      final sub = _dbRef.child(_chats[i].id).limitToLast(50).onValue.listen((event) {
        if (event.snapshot.value != null) {
          final rawVal = event.snapshot.value;
          if (rawVal is Map) {
            final Map<dynamic, dynamic> data = rawVal;
            if (data.isNotEmpty) {
              int unread = 0;
              dynamic lastMsgData;
              int maxTimestamp = 0;

              data.forEach((key, value) {
                if (value is Map) {
                  final timestamp = _extractTimestamp(value['timestamp']);
                  if (timestamp >= maxTimestamp) {
                    maxTimestamp = timestamp;
                    lastMsgData = value;
                  }
                  if (value['senderId'] != null && value['senderId'] != _currentUserId && value['isRead'] != true) {
                    unread++;
                  }
                }
              });
              
              final String text = lastMsgData?['text'] ?? (lastMsgData?['imageUrl'] != null ? 'Sent an image' : '');
              final int timestamp = _extractTimestamp(lastMsgData?['timestamp']);
              
              if (mounted) {
                setState(() {
                  _chats[i] = _chats[i].copyWith(
                    lastMessage: text.isNotEmpty ? text : 'Tap to chat',
                    time: _formatTimestamp(timestamp),
                    timestamp: timestamp,
                    unreadCount: unread,
                  );
                });
              }
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _chats[i] = _chats[i].copyWith(
                lastMessage: 'Tap to chat',
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
                final timestamp = _extractTimestamp(value['timestamp']);
                if (timestamp >= maxTimestamp) {
                  maxTimestamp = timestamp;
                  lastMsgData = value;
                }
                if (value['senderId'] != null && value['senderId'] != _currentUserId && value['isRead'] != true) {
                  unread++;
                }
              }
            });
            
            if (lastMsgData != null && mounted) {
              final String text = (lastMsgData['text'] ?? (lastMsgData['imageUrl'] != null ? 'Sent an image' : '')).toString();
              final int timestamp = _extractTimestamp(lastMsgData['timestamp']);
              final String? senderName = lastMsgData['senderName']?.toString();
              
              setState(() {
                _dynamicChatData[chat.id] = {
                  'text': text.isNotEmpty ? text : 'Tap to chat',
                  'timestamp': timestamp,
                  'time': _formatTimestamp(timestamp),
                  'unreadCount': unread,
                  'senderName': senderName,
                };
                
                final staticIndex = _chats.indexWhere((c) => c.id == chat.id);
                if (staticIndex != -1) {
                  _chats[staticIndex] = _chats[staticIndex].copyWith(
                    lastMessage: text.isNotEmpty ? text : 'Tap to chat',
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
          final List<ChatSummary> allBookingChats = [];
          final Map<String, ChatSummary> providerChatMap = {};

          for (var booking in bookings) {
            final status = (booking['status'] ?? '').toString().toLowerCase().trim();
            final isCancelled = status == 'cancelled';
            final bookingId = (booking['id'] ?? '').toString().trim();
            if (bookingId.isEmpty) continue;

            final String chatId = 'bookings/$bookingId';
            if (isCancelled && !_dynamicChatData.containsKey(chatId)) continue;

            final shopId = (booking['shopId'] ?? booking['ownerId'] ?? booking['vendorId'] ?? '').toString().trim();
            final rawShopName = (booking['shopName'] ?? booking['businessName'] ?? booking['workshopName'] ?? '').toString().trim();
            final shopName = (rawShopName.isNotEmpty && rawShopName.toLowerCase() != 'workshop')
                ? rawShopName
                : '';

            final workerId = (booking['workerId'] ?? '').toString().trim();
            final rawWorkerName = (booking['workerName'] ?? '').toString().trim();
            final workerName = (rawWorkerName.isNotEmpty &&
                    rawWorkerName.toLowerCase() != 'provider' &&
                    rawWorkerName.toLowerCase() != 'service provider' &&
                    rawWorkerName.toLowerCase() != 'workshop')
                ? rawWorkerName
                : '';

            final isShop = shopId.isNotEmpty || shopName.isNotEmpty;
            final String name = isShop
                ? (shopName.isNotEmpty ? shopName : 'Workshop')
                : (workerName.isNotEmpty ? workerName : 'Service Provider');
            final String serviceName = (booking['serviceTitle'] ?? booking['serviceName'] ?? (isShop ? 'Workshop' : 'Service Provider')).toString();
            final String? image = isShop
                ? (booking['shopImage'] ?? booking['imagePath'] ?? booking['imageUrl'])
                : booking['workerImage'];

            final candidate = ChatSummary(
              id: chatId,
              name: name,
              role: serviceName,
              lastMessage: 'Tap to chat',
              time: '',
              unreadCount: 0,
              avatarType: 'icon',
              avatarIcon: isShop ? Icons.storefront_rounded : Icons.person,
              avatarBgColor: isShop ? const Color(0xFF2029C5) : const Color(0xFF10B981),
              category: isShop ? 'Shop' : 'Provider',
              imageUrl: image,
              workerId: workerId.isNotEmpty ? workerId : null,
              shopId: shopId.isNotEmpty ? shopId : null,
            );

            allBookingChats.add(candidate);

            // Group by distinct provider identity so each provider appears only once
            final String providerKey = shopId.isNotEmpty
                ? 'shop_$shopId'
                : (workerId.isNotEmpty
                    ? 'worker_$workerId'
                    : (name.isNotEmpty && name != 'Service Provider' && name != 'Workshop'
                        ? 'provider_$name'
                        : 'booking_$bookingId'));

            if (!providerChatMap.containsKey(providerKey)) {
              providerChatMap[providerKey] = candidate;
            } else {
              // Keep the conversation with the latest message timestamp or most active
              final existing = providerChatMap[providerKey]!;
              final existingTime = _dynamicChatData[existing.id]?['timestamp'] ?? 0;
              final candidateTime = _dynamicChatData[candidate.id]?['timestamp'] ?? 0;
              if ((candidateTime as num) > (existingTime as num)) {
                providerChatMap[providerKey] = candidate;
              }
            }
          }

          final dynamicChats = [
            ..._chats,
            ...providerChatMap.values,
          ];

          // Listen to all booking chat nodes in RTDB
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _listenToDynamicChats([..._chats, ...allBookingChats]);
            }
          });

          // Support chat always at top, then others sorted by timestamp
          final supportChats = dynamicChats.where((c) => c.category == 'Support').toList();
          final otherChats = dynamicChats.where((c) => c.category != 'Support').toList()
            ..sort((a, b) {
              final aTime = _dynamicChatData[a.id]?['timestamp'] ?? a.timestamp ?? 0;
              final bTime = _dynamicChatData[b.id]?['timestamp'] ?? b.timestamp ?? 0;
              return (bTime as num).compareTo(aTime as num);
            });

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

    // 1. If it's explicitly a Shop (or has shopId), stream from shops collection
    if ((chat.category == 'Shop' || chat.shopId != null) && chat.shopId != null && chat.shopId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('shops').doc(chat.shopId).snapshots(),
        builder: (context, snapshot) {
          String displayName = chat.name;
          String? displayImg = chat.imageUrl;
          bool isVerified = chat.isVerified;

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final shopData = snapshot.data!.data();
            if (shopData != null) {
              final sName = (shopData['shopName'] ?? shopData['businessName'] ?? shopData['name'])?.toString();
              if (sName != null && sName.trim().isNotEmpty) {
                displayName = sName.trim();
              }
              final sImg = (shopData['shopImage'] ?? shopData['bannerImage'] ?? shopData['profilePic'] ?? shopData['imageUrl'])?.toString();
              if (sImg != null && sImg.trim().isNotEmpty) {
                displayImg = sImg.trim();
              }
              final status = (shopData['status'] ?? '').toString().toLowerCase();
              if (status == 'approved' || status == 'active' || shopData['isVerified'] == true) {
                isVerified = true;
              }
            }
          }

          return _buildChatTileContent(
            context: context,
            chat: chat,
            displayName: displayName,
            displayImg: displayImg,
            isVerified: isVerified,
            displayMsg: displayMsg,
            displayTime: displayTime,
            unreadCount: unreadCount,
            recipientId: chat.shopId,
            recipientRole: 'shop',
          );
        },
      );
    }

    // 2. If it's a Provider/Worker, check shops first (in case it's a workshop owner), then workers collection
    if (chat.category == 'Provider' && chat.workerId != null && chat.workerId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('shops').doc(chat.workerId).snapshots(),
        builder: (context, shopSnap) {
          if (shopSnap.hasData && shopSnap.data != null && shopSnap.data!.exists) {
            final shopData = shopSnap.data!.data();
            String displayName = chat.name;
            String? displayImg = chat.imageUrl;
            bool isVerified = false;

            if (shopData != null) {
              final sName = (shopData['shopName'] ?? shopData['businessName'] ?? shopData['name'])?.toString();
              if (sName != null && sName.trim().isNotEmpty) {
                displayName = sName.trim();
              }
              final sImg = (shopData['shopImage'] ?? shopData['bannerImage'] ?? shopData['profilePic'] ?? shopData['imageUrl'])?.toString();
              if (sImg != null && sImg.trim().isNotEmpty) {
                displayImg = sImg.trim();
              }
              final status = (shopData['status'] ?? '').toString().toLowerCase();
              if (status == 'approved' || status == 'active' || shopData['isVerified'] == true) {
                isVerified = true;
              }
            }

            final updatedShopChat = chat.copyWith(
              name: displayName,
              role: 'Workshop',
              avatarIcon: Icons.storefront_rounded,
              avatarBgColor: const Color(0xFF2029C5),
              category: 'Shop',
              imageUrl: displayImg,
              isVerified: isVerified,
              shopId: chat.workerId,
            );

            return _buildChatTileContent(
              context: context,
              chat: updatedShopChat,
              displayName: displayName,
              displayImg: displayImg,
              isVerified: isVerified,
              displayMsg: displayMsg,
              displayTime: displayTime,
              unreadCount: unreadCount,
              recipientId: chat.workerId,
              recipientRole: 'shop',
            );
          }

          // Otherwise, it's a genuine worker
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('workers').doc(chat.workerId).snapshots(),
            builder: (context, snapshot) {
              String displayName = chat.name;
              String? displayImg = chat.imageUrl;
              bool isVerified = chat.isVerified;

              if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                final workerData = snapshot.data!.data();
                if (workerData != null) {
                  final wName = (workerData['name'] ?? workerData['fullName'])?.toString();
                  if (wName != null && wName.trim().isNotEmpty) {
                    displayName = wName.trim();
                  }
                  if (workerData['profilePic'] != null && workerData['profilePic'].toString().isNotEmpty) {
                    displayImg = workerData['profilePic'].toString();
                  } else if (workerData['imageUrl'] != null && workerData['imageUrl'].toString().isNotEmpty) {
                    displayImg = workerData['imageUrl'].toString();
                  }
                  final status = (workerData['status'] ?? '').toString().toLowerCase();
                  if (workerData['isApproved'] == true || status == 'approved' || status == 'active') {
                    isVerified = true;
                  }
                }
              }

              return _buildChatTileContent(
                context: context,
                chat: chat,
                displayName: displayName,
                displayImg: displayImg,
                isVerified: isVerified,
                displayMsg: displayMsg,
                displayTime: displayTime,
                unreadCount: unreadCount,
                recipientId: chat.workerId,
                recipientRole: 'worker',
              );
            },
          );
        },
      );
    }

    // For Support, Promotions, etc.
    return _buildChatTileContent(
      context: context,
      chat: chat,
      displayName: chat.name,
      displayImg: chat.imageUrl,
      isVerified: chat.isVerified,
      displayMsg: displayMsg,
      displayTime: displayTime,
      unreadCount: unreadCount,
      recipientId: null,
      recipientRole: null,
    );
  }

  Widget _buildChatTileContent({
    required BuildContext context,
    required ChatSummary chat,
    required String displayName,
    required String? displayImg,
    required bool isVerified,
    required String displayMsg,
    required String displayTime,
    required int unreadCount,
    required String? recipientId,
    required String? recipientRole,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              providerName: displayName,
              providerRole: chat.role,
              bookingId: chat.id,
              isReadOnly: chat.category == 'Promotions',
              avatarType: displayImg != null && displayImg.isNotEmpty ? 'image' : chat.avatarType,
              avatarText: chat.avatarText,
              avatarIcon: chat.avatarIcon,
              avatarBgColor: chat.avatarBgColor,
              imageUrl: displayImg,
              recipientId: recipientId,
              recipientRole: recipientRole,
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: chat.avatarBgColor,
                borderRadius: BorderRadius.circular(16),
                image: displayImg != null && displayImg.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(displayImg),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (displayImg == null || displayImg.isEmpty)
                  ? Center(
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
                    )
                  : null,
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
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
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
  final String? shopId;

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
    this.shopId,
  });

  ChatSummary copyWith({
    String? name,
    String? role,
    String? lastMessage,
    String? time,
    int? timestamp,
    String? imageUrl,
    int? unreadCount,
    String? avatarType,
    String? avatarText,
    IconData? avatarIcon,
    Color? avatarBgColor,
    String? category,
    bool? isVerified,
    String? workerId,
    String? shopId,
  }) {
    return ChatSummary(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarType: avatarType ?? this.avatarType,
      avatarText: avatarText ?? this.avatarText,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarBgColor: avatarBgColor ?? this.avatarBgColor,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isVerified: isVerified ?? this.isVerified,
      workerId: workerId ?? this.workerId,
      shopId: shopId ?? this.shopId,
    );
  }
}
