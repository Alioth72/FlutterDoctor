import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/chat_storage_repository.dart';

/// Lightweight, zero-native-dependency implementation of [ChatStorageRepository]
/// powered by [SharedPreferences] and memory caching with broadcast streams.
class PreferencesChatStorageRepository implements ChatStorageRepository {
  static const String _prefKey = 'patient_chatbot_messages_store_v1';
  final List<ChatMessage> _messages = [];
  final StreamController<List<ChatMessage>> _streamController =
      StreamController<List<ChatMessage>>.broadcast();

  int _nextId = 1;
  bool _isInitialized = false;

  @override
  Future<void> init({String? directory}) async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _messages.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final msg = ChatMessage.fromMap(item);
            _messages.add(msg);
            if (msg.id >= _nextId) {
              _nextId = msg.id + 1;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PreferencesChatStorageRepository] Init cache note: $e');
    }

    _isInitialized = true;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => m.toMap()).toList();
      await prefs.setString(_prefKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[PreferencesChatStorageRepository] Persist note: $e');
    }
  }

  void _notify(String conversationId) {
    if (!_streamController.isClosed) {
      final convMessages = _messages
          .where((m) => m.conversationId == conversationId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _streamController.add(List.unmodifiable(convMessages));
    }
  }

  @override
  Future<ChatMessage> saveMessage(ChatMessage message) async {
    final assignedId = message.id == 0 ? _nextId++ : message.id;
    final stored = message.copyWith(id: assignedId);
    _messages.add(stored);
    await _persist();
    _notify(stored.conversationId);
    return stored;
  }

  @override
  Future<List<ChatMessage>> saveMessages(List<ChatMessage> messages) async {
    final saved = <ChatMessage>[];
    for (final m in messages) {
      final assignedId = m.id == 0 ? _nextId++ : m.id;
      saved.add(m.copyWith(id: assignedId));
    }
    _messages.addAll(saved);
    await _persist();
    if (saved.isNotEmpty) {
      _notify(saved.first.conversationId);
    }
    return saved;
  }

  @override
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId) async {
    final list = _messages
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  @override
  Future<ChatMessage?> getMessageById(int id) async {
    try {
      return _messages.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateMessage(ChatMessage message) async {
    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      _messages[idx] = message;
      await _persist();
      _notify(message.conversationId);
    }
  }

  @override
  Future<bool> deleteMessage(int id) async {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final convId = _messages[idx].conversationId;
      _messages.removeAt(idx);
      await _persist();
      _notify(convId);
      return true;
    }
    return false;
  }

  @override
  Future<int> deleteConversation(String conversationId) async {
    final before = _messages.length;
    _messages.removeWhere((m) => m.conversationId == conversationId);
    final count = before - _messages.length;
    if (count > 0) {
      await _persist();
      _notify(conversationId);
    }
    return count;
  }

  @override
  Future<void> clearAll() async {
    _messages.clear();
    await _persist();
    if (!_streamController.isClosed) {
      _streamController.add([]);
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId) {
    // Return an auto-updating stream initialized with current conversation messages
    late StreamController<List<ChatMessage>> controller;
    StreamSubscription<List<ChatMessage>>? sub;

    controller = StreamController<List<ChatMessage>>(
      onListen: () {
        final current = _messages
            .where((m) => m.conversationId == conversationId)
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        controller.add(current);

        sub = _streamController.stream.listen((all) {
          if (!controller.isClosed) {
            controller.add(all);
          }
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<List<ChatMessage>> getUnsyncedMessages() async {
    return _messages.where((m) => !m.isSynced).toList();
  }

  @override
  Future<void> markAsSynced(List<int> messageIds) async {
    bool updated = false;
    for (int i = 0; i < _messages.length; i++) {
      if (messageIds.contains(_messages[i].id)) {
        _messages[i] = _messages[i].copyWith(isSynced: true);
        updated = true;
      }
    }
    if (updated) {
      await _persist();
    }
  }

  @override
  Future<void> close() async {
    await _streamController.close();
  }
}
