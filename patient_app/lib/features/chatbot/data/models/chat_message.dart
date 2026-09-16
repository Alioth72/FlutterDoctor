enum MessageRole {
  user,
  bot,
}

class ChatMessage {
  ChatMessage({
    this.id = 0,
    required this.conversationId,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isUrgent = false,
    this.isSynced = false,
  });

  int id;
  final String conversationId;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final bool isUrgent;
  final bool isSynced;

  ChatMessage copyWith({
    int? id,
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
      'id': id == 0 ? null : id,
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
      id: map['id'] as int? ?? 0,
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
