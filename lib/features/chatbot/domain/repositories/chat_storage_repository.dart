import '../../data/models/chat_message.dart';
export '../../data/models/chat_message.dart';

/// Abstract contract for local chat persistence.
abstract class ChatStorageRepository {
  /// Initializes the database instance.
  Future<void> init({String? directory});

  /// Saves a single message to local storage and returns it with its generated ID.
  Future<ChatMessage> saveMessage(ChatMessage message);

  /// Saves a batch of messages.
  Future<List<ChatMessage>> saveMessages(List<ChatMessage> messages);

  /// Retrieves all messages for a specific conversation in chronological order.
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId);

  /// Retrieves a single message by its ID.
  Future<ChatMessage?> getMessageById(int id);

  /// Updates an existing message.
  Future<void> updateMessage(ChatMessage message);

  /// Deletes a message by its ID.
  Future<bool> deleteMessage(int id);

  /// Deletes all messages belonging to a conversation. Returns deleted count.
  Future<int> deleteConversation(String conversationId);

  /// Clears all messages across all conversations.
  Future<void> clearAll();

  /// Reactive stream of messages for a given conversation.
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId);

  /// Retrieves messages that have not yet been synced to backend (for background sync).
  Future<List<ChatMessage>> getUnsyncedMessages();

  /// Marks a list of messages as synced.
  Future<void> markAsSynced(List<int> messageIds);

  /// Closes the database.
  Future<void> close();
}
