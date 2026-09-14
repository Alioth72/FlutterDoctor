import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:chatbot_healthcare/features/chatbot/chatbot_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late IsarChatStorageRepository repository;

  setUpAll(() async {
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_chat_test_');
    repository = IsarChatStorageRepository();
    await repository.init(directory: tempDir.path);
  });

  tearDown(() async {
    await repository.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('IsarChatStorageRepository', () {
    test('saves and retrieves messages for a conversation in chronological order', () async {
      final now = DateTime.now();
      final msg1 = ChatMessage(
        conversationId: 'conv_1',
        role: MessageRole.user,
        text: 'Hello doctor, I have a mild fever.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      );
      final msg2 = ChatMessage(
        conversationId: 'conv_1',
        role: MessageRole.bot,
        text: 'Hello! How long have you had this fever?',
        timestamp: now.subtract(const Duration(minutes: 4)),
      );
      final msg3 = ChatMessage(
        conversationId: 'conv_2',
        role: MessageRole.user,
        text: 'Message for other conversation',
        timestamp: now,
      );

      await repository.saveMessage(msg1);
      await repository.saveMessage(msg2);
      await repository.saveMessage(msg3);

      final conv1Messages = await repository.getMessagesForConversation('conv_1');
      expect(conv1Messages.length, 2);
      expect(conv1Messages[0].text, 'Hello doctor, I have a mild fever.');
      expect(conv1Messages[0].role, MessageRole.user);
      expect(conv1Messages[1].text, 'Hello! How long have you had this fever?');
      expect(conv1Messages[1].role, MessageRole.bot);
    });

    test('stores and flags urgent messages properly', () async {
      final urgentMsg = ChatMessage(
        conversationId: 'conv_urgent',
        role: MessageRole.user,
        text: 'Severe chest pain radiating to left arm',
        timestamp: DateTime.now(),
        isUrgent: true,
      );

      final saved = await repository.saveMessage(urgentMsg);
      final fetched = await repository.getMessageById(saved.id);

      expect(fetched, isNotNull);
      expect(fetched!.isUrgent, isTrue);
      expect(fetched.text, contains('chest pain'));
    });

    test('deletes all messages in a specific conversation', () async {
      final now = DateTime.now();
      await repository.saveMessages([
        ChatMessage(
          conversationId: 'conv_to_delete',
          role: MessageRole.user,
          text: 'Hi',
          timestamp: now,
        ),
        ChatMessage(
          conversationId: 'conv_to_delete',
          role: MessageRole.bot,
          text: 'Hello',
          timestamp: now.add(const Duration(seconds: 1)),
        ),
        ChatMessage(
          conversationId: 'conv_keep',
          role: MessageRole.user,
          text: 'Keep me',
          timestamp: now,
        ),
      ]);

      final deletedCount = await repository.deleteConversation('conv_to_delete');
      expect(deletedCount, 2);

      final remainingConv = await repository.getMessagesForConversation('conv_to_delete');
      expect(remainingConv, isEmpty);

      final keptMessages = await repository.getMessagesForConversation('conv_keep');
      expect(keptMessages.length, 1);
    });

    test('tracks unsynced messages and marks them synced', () async {
      final now = DateTime.now();
      final msg = await repository.saveMessage(
        ChatMessage(
          conversationId: 'conv_sync',
          role: MessageRole.user,
          text: 'Offline question',
          timestamp: now,
          isSynced: false,
        ),
      );

      final unsynced = await repository.getUnsyncedMessages();
      expect(unsynced.length, 1);
      expect(unsynced.first.id, msg.id);

      await repository.markAsSynced([msg.id]);

      final unsyncedAfter = await repository.getUnsyncedMessages();
      expect(unsyncedAfter, isEmpty);
    });

    test('watchMessagesForConversation emits updates when new message is saved', () async {
      final stream = repository.watchMessagesForConversation('conv_stream');
      
      expect(
        stream,
        emitsInOrder([
          isEmpty, // Initial emission
          predicate<List<ChatMessage>>((list) => list.length == 1 && list.first.text == 'First'),
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await repository.saveMessage(
        ChatMessage(
          conversationId: 'conv_stream',
          role: MessageRole.user,
          text: 'First',
          timestamp: DateTime.now(),
        ),
      );
    });
  });
}
