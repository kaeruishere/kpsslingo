import 'dart:convert';

class PushNotificationModel {
  final String id;
  final String title;
  final String body;
  final String contentId;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  PushNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.contentId,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  PushNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? contentId,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return PushNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      contentId: contentId ?? this.contentId,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'contentId': contentId,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PushNotificationModel.fromMap(Map<String, dynamic> map) {
    return PushNotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      contentId: map['contentId'] ?? '',
      type: map['type'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory PushNotificationModel.fromJson(String source) => PushNotificationModel.fromMap(json.decode(source));
}
