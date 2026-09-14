import 'package:isar/isar.dart';

part 'chat_message.g.dart';

enum MessageRole {
  user,
  bot,
}

@collection
class ChatMessage {
  ChatMessage({
    this.id = Isar.autoIncrement,
    required this.conversationId,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isUrgent = false,
    this.isSynced = false,
  });

  Id id;

  @Index(composite: [CompositeIndex('timestamp')])
  final String conversationId;

  @Enumerated(EnumType.name)
  final MessageRole role;

  final String text;

  @Index()
  final DateTime timestamp;

  final bool isUrgent;

  final bool isSynced;

  ChatMessage copyWith({
    Id? id,
    String? conversationId,
    MessageRole? role,
    String? text,
    DateTime? timestamp,
    bool? isUrgent,
    bool? isSynced,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isUrgent: isUrgent ?? this.isUrgent,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == Isar.autoIncrement ? null : id,
      'conversationId': conversationId,
      'role': role.name,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isUrgent': isUrgent,
      'isSynced': isSynced,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int? ?? Isar.autoIncrement,
      conversationId: map['conversationId'] as String? ?? '',
      role: MessageRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => MessageRole.user,
      ),
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      isUrgent: map['isUrgent'] as bool? ?? false,
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, conv: $conversationId, role: ${role.name}, urgent: $isUrgent, text: ${text.length > 30 ? '${text.substring(0, 30)}...' : text})';
  }
}
