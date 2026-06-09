import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/cloudinary_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String providerName;
  final String providerRole;
  final String bookingId;
  final bool isReadOnly;
  final String avatarType; // 'text' or 'icon'
  final String? avatarText;
  final IconData? avatarIcon;
  final Color? avatarBgColor;
  final String? imageUrl;
  final String? recipientId;
  final String? recipientRole; // 'user' or 'worker'

  const ChatScreen({
    super.key,
    required this.providerName,
    required this.providerRole,
    required this.bookingId,
    this.isReadOnly = false,
    this.avatarType = 'icon',
    this.avatarText,
    this.avatarIcon = Icons.person,
    this.avatarBgColor,
    this.imageUrl,
    this.recipientId,
    this.recipientRole,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseReference _dbRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://urbanservices-d34d2-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).ref();

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _chatPath {
    if (widget.recipientId != null &&
        widget.recipientId!.isNotEmpty &&
        widget.recipientId != 'support') {
      final List<String> ids = [_currentUserId, widget.recipientId!]..sort();
      return 'direct_chats/${ids[0]}_${ids[1]}';
    }
    return widget.bookingId;
  }

  List<Map<String, dynamic>> _messages = [];

  bool _isLoading = true;
  bool _isUploading = false;
  bool _isLocationLoading = false;

  @override
  void initState() {
    super.initState();
    _listenForMessages();
  }

  void _listenForMessages() {
    _dbRef.child(_chatPath).onValue.listen((event) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (event.snapshot.value != null) {
        final List<Map<String, dynamic>> loadedMessages = [];

        try {
          if (event.snapshot.value is Map) {
            final Map<dynamic, dynamic> data =
                event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) {
              _processMessage(key, value, loadedMessages);
            });
          } else if (event.snapshot.value is List) {
            final List<dynamic> data = event.snapshot.value as List<dynamic>;
            for (int i = 0; i < data.length; i++) {
              if (data[i] != null) {
                _processMessage(i.toString(), data[i], loadedMessages);
              }
            }
          }
        } catch (e) {
          print('Error parsing chat messages: $e');
        }

        // Sort by timestamp (descending for reverse ListView)
        loadedMessages.sort((a, b) {
          final aTime = _getSafeTimestamp(a['timestamp']);
          final bTime = _getSafeTimestamp(b['timestamp']);
          return bTime.compareTo(aTime);
        });

        if (mounted) {
          setState(() {
            _messages = loadedMessages;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _messages = [];
          });
        }
      }
    });
  }

  void _processMessage(
    String key,
    dynamic value,
    List<Map<String, dynamic>> targetList,
  ) {
    if (value is! Map) return;

    String time = value['time'] ?? '';
    if (time.isEmpty && value['timestamp'] != null) {
      final DateTime dt = DateTime.fromMillisecondsSinceEpoch(
        value['timestamp'],
      );
      time = DateFormat('hh:mm a').format(dt);
    }

    // Mark as read if it's from the other person
    if (value['senderId'] != _currentUserId && value['isRead'] != true) {
      _dbRef.child(_chatPath).child(key).update({'isRead': true});
    }

    targetList.add({
      'message': value['text'],
      'senderId': value['senderId'],
      'isMe': value['senderId'] == _currentUserId,
      'time': time,
      'timestamp': _getSafeTimestamp(value['timestamp']),
      'imageUrl': value['imageUrl'],
    });
  }

  int _getSafeTimestamp(dynamic timestamp) {
    if (timestamp is int) return timestamp;
    if (timestamp is double) return timestamp.toInt();
    if (timestamp is Map)
      return DateTime.now()
          .millisecondsSinceEpoch; // Fallback for ServerValue placeholder
    return 0;
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _containsPhoneNumber(String text) {
    // This regex looks for 10 or more digits that may be separated by spaces or hyphens
    final RegExp phoneRegex = RegExp(r'(?:\d[\s-]?){10,}');
    return phoneRegex.hasMatch(text);
  }

  void _sendMessage({String? text, String? imageUrl}) {
    if ((text != null && text.trim().isNotEmpty) || imageUrl != null) {
      final String? finalMsg = text?.trim();

      // Prevent sending phone numbers (but allow location links with coordinates)
      final bool isLocationMessage = finalMsg != null &&
          RegExp(r'https:\/\/www\.google\.com\/maps\?q=').hasMatch(finalMsg);
      if (finalMsg != null && !isLocationMessage && _containsPhoneNumber(finalMsg)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "For your safety, sharing phone numbers is not allowed.",
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final String time = DateFormat('hh:mm a').format(DateTime.now());
      final String senderName =
          ref.read(userDataProvider).value?['name'] ??
          (widget.recipientRole == 'worker' ? 'Customer' : 'Professional');

      final Map<String, dynamic> msgData = {
        'senderId': _currentUserId,
        'senderName': senderName,
        'time': time,
        'timestamp': ServerValue.timestamp,
        'isRead': false,
      };

      if (finalMsg != null) msgData['text'] = finalMsg;
      if (imageUrl != null) msgData['imageUrl'] = imageUrl;

      final newMsgRef = _dbRef.child(_chatPath).push();
      newMsgRef.set(msgData);

      // 🔔 Send Notification via Realtime Database
      if (widget.recipientId != null && widget.recipientId!.isNotEmpty) {
        final String notificationTitle = "New Message from $senderName";
        final String notificationBody = imageUrl != null
            ? "Sent an image"
            : (finalMsg ?? "New message");

        _dbRef.child('notifications/${widget.recipientId}').push().set({
          'title': notificationTitle,
          'message': notificationBody,
          'type': 'chat',
          'bookingId': widget.bookingId.split('/').last,
          'senderId': _currentUserId,
          'timestamp': ServerValue.timestamp,
          'createdAt': ServerValue.timestamp,
          'isRead': false,
        });
      }

      _messageController.clear();
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isUploading = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final String? imageUrl = await CloudinaryService.uploadImage(
          File(image.path),
          folder: 'chat_messages',
        );

        if (imageUrl != null) {
          _sendMessage(imageUrl: imageUrl);
        }
      }
    } catch (e) {
      print('Error picking/uploading image: $e');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final String mapsLink =
            "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
        final String message = "My current location: $mapsLink";
        _sendMessage(text: message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Could not get location: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2029C5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Colors.black,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.avatarBgColor ?? Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                image: widget.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.imageUrl != null
                  ? null
                  : Center(
                      child: widget.avatarType == 'text'
                          ? Text(
                              widget.avatarText ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Icon(
                              widget.avatarIcon,
                              color: widget.avatarBgColor != null
                                  ? Colors.white
                                  : Colors.grey,
                              size: 20,
                            ),
                    ),
            ),
            const SizedBox(width: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.providerName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!widget.isReadOnly && widget.providerRole != 'Promo') ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Online',
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: 6,
                    itemBuilder: (context, index) =>
                        _buildSkeletonBubble(index % 2 == 0),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageBubble(
                        msg['message'],
                        msg['isMe'],
                        msg['time'],
                        primaryGreen,
                        imageUrl: msg['imageUrl'],
                      );
                    },
                  ),
          ),
          if (!widget.isReadOnly) _buildInputBar(primaryGreen),
        ],
      ),
    );
  }

  Widget _buildSkeletonBubble(bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildSkeletonContainer(
            height: 45,
            width:
                MediaQuery.of(context).size.width * (0.4 + (isMe ? 0.2 : 0.35)),
            borderRadius: 20,
          ),
          const SizedBox(height: 6),
          _buildSkeletonContainer(height: 10, width: 40, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildSkeletonContainer({
    required double height,
    required double width,
    double borderRadius = 12,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey.shade100,
                      Colors.grey.shade50,
                      Colors.grey.shade100,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(
    double lat,
    double lon,
    bool isMe,
    Color themeColor,
    String url,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isMe ? themeColor : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? themeColor.withOpacity(0.95) : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: isMe ? Colors.white : themeColor,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shared Location',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current location shared',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: themeColor.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _launchURL(url),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 18,
                              color: themeColor,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Open Location',
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String? message,
    bool isMe,
    String time,
    Color themeColor, {
    String? imageUrl,
  }) {
    final locationRegex = RegExp(
      r'https:\/\/www\.google\.com\/maps\?q=(-?\d+\.\d+),(-?\d+\.\d+)',
    );
    final hasLocation = message != null && locationRegex.hasMatch(message);

    double? lat;
    double? lon;
    String? locationUrl;
    if (hasLocation) {
      final match = locationRegex.firstMatch(message);
      if (match != null) {
        lat = double.tryParse(match.group(1) ?? '');
        lon = double.tryParse(match.group(2) ?? '');
        locationUrl = match.group(0);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: (imageUrl != null || hasLocation)
                ? const EdgeInsets.all(4)
                : const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? themeColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          message != null && message.isNotEmpty && !hasLocation
                          ? 8
                          : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                if (hasLocation &&
                    lat != null &&
                    lon != null &&
                    locationUrl != null)
                  _buildLocationCard(lat, lon, isMe, themeColor, locationUrl),
                if (message != null && message.isNotEmpty && !hasLocation)
                  Padding(
                    padding: imageUrl != null
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          )
                        : EdgeInsets.zero,
                    child: Builder(
                      builder: (context) {
                        final urlRegex = RegExp(r'(https?:\/\/[^\s]+)');
                        final match = urlRegex.firstMatch(message);

                        if (match != null) {
                          final String url = match.group(0)!;
                          return GestureDetector(
                            onTap: () => _launchURL(url),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: message.substring(0, match.start),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : const Color(0xFF2C3E50),
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  TextSpan(
                                    text: url,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : themeColor,
                                      fontSize: 15,
                                      height: 1.4,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: message.substring(match.end),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : const Color(0xFF2C3E50),
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Text(
                          message,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF2C3E50),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color themeColor) {
    final bool isButtonsDisabled = _isUploading || _isLocationLoading;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: Colors.grey,
                      ),
                onPressed: isButtonsDisabled ? null : _pickImage,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLocationLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_rounded, color: Colors.grey),
                onPressed: isButtonsDisabled ? null : _shareLocation,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  onSubmitted: isButtonsDisabled
                      ? null
                      : (_) => _sendMessage(text: _messageController.text),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isButtonsDisabled
                  ? null
                  : () => _sendMessage(text: _messageController.text),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isButtonsDisabled ? Colors.grey : themeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
