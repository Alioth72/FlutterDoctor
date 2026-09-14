import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/chat_storage_repository.dart';

/// Implementation of [ChatStorageRepository] powered by Isar Database.
class IsarChatStorageRepository implements ChatStorageRepository {
  IsarChatStorageRepository([this._isar]);

  Isar? _isar;

  /// Returns true if the underlying Isar instance is opened and active.
  bool get isInitialized => _isar != null && _isar!.isOpen;

  /// Underlying Isar instance (throws StateError if not initialized).
  Isar get isar {
    final instance = _isar;
    if (instance == null || !instance.isOpen) {
      throw StateError('Isar database is not initialized. Call init() first.');
    }
    return instance;
  }

  @override
  Future<void> init({String? directory}) async {
    if (isInitialized) return;

    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
    _isar = await Isar.open(
      [ChatMessageSchema],
      directory: dir,
      name: 'healthcare_chat',
      inspector: false,
    );
  }

  @override
  Future<ChatMessage> saveMessage(ChatMessage message) async {
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
    return message;
  }

  @override
  Future<List<ChatMessage>> saveMessages(List<ChatMessage> messages) async {
    await isar.writeTxn(() async {
      await isar.chatMessages.putAll(messages);
    });
    return messages;
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId) async {
    return await isar.chatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByTimestamp()
        .findAll();
  }

  @override
  Future<ChatMessage?> getMessageById(int id) async {
    return await isar.chatMessages.get(id);
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    await isar.writeTxn(() async {
      await isar.chatMessages.put(message);
    });
  }

  @override
  Future<bool> deleteMessage(int id) async {
    return await isar.writeTxn(() async {
      return await isar.chatMessages.delete(id);
    });
  }

  @override
  Future<int> deleteConversation(String conversationId) async {
    return await isar.writeTxn(() async {
      return await isar.chatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .deleteAll();
    });
  }

  @override
  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.chatMessages.clear();
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId) {
    return isar.chatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByTimestamp()
        .build()
        .watch(fireImmediately: true);
  }

  @override
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    return await isar.chatMessages
        .filter()
        .isSyncedEqualTo(false)
        .sortByTimestamp()
        .findAll();
  }

  @override
  Future<void> markAsSynced(List<int> messageIds) async {
    await isar.writeTxn(() async {
      final messages = await isar.chatMessages.getAll(messageIds);
      final updated = <ChatMessage>[];
      for (final msg in messages) {
        if (msg != null) {
          updated.add(msg.copyWith(isSynced: true));
        }
      }
      if (updated.isNotEmpty) {
        await isar.chatMessages.putAll(updated);
      }
    });
  }

  @override
  Future<void> close() async {
    if (isInitialized) {
      await _isar!.close();
      _isar = null;
    }
  }
}
