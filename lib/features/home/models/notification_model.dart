class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String type; // e.g., 'discount', 'update', 'system'
  final bool isRead;
  final String? bookingId;
  final String? senderId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.type = 'system',
    this.isRead = false,
    this.bookingId,
    this.senderId,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? map['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      type: map['type'] ?? 'system',
      isRead: map['isRead'] ?? (map['status'] == 'read'),
      bookingId: map['bookingId']?.toString(),
      senderId: map['senderId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type,
      'isRead': isRead,
      'bookingId': bookingId,
      'senderId': senderId,
    };
  }
}
