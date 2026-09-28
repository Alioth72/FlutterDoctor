import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/language_provider.dart';
import '../../../../services/stt/sarvam_stt_service.dart';
import '../../../../services/tts/sarvam_tts_service.dart';
import '../../domain/models/patient_profile.dart';
import '../../domain/repositories/chat_storage_repository.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/services/chat_orchestrator.dart';
import '../../domain/services/connectivity_service.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/formatted_message_view.dart';

/// Primary conversational screen for the Healthcare Chatbot with 22-language Sarvam TTS.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.orchestrator,
    required this.storageRepository,
    required this.connectivityService,
    required this.cloudLlmClient,
    this.patientRepository,
    this.conversationId = 'default_conversation',
  });

  final ChatOrchestrator orchestrator;
  final ChatStorageRepository storageRepository;
  final ConnectivityService connectivityService;
  final dynamic cloudLlmClient;
  final PatientRepository? patientRepository;
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isGenerating = false;
  bool _isOnline = false;
  bool _showEmergencyBanner = true;
  bool _showPatientDetails = false;
  PatientProfile? _patientProfile;
  StreamSubscription<bool>? _connectivitySub;

  static const List<String> _suggestions = [
    'Can I take Amoxicillin for my cold?',
    'How do I scan prescriptions for Jan Aushadhi savings?',
    'How to measure my Heart Rate using Face Vitals?',
    'How to request an ASHA worker home visit?',
    'What happens when I press the red Emergency SOS button?',
    'How do I switch the app to Hindi or other languages?',
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _loadPatientProfile();
    _connectivitySub =
        widget.connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOnline = online;
        });
      }
    });
  }

  Future<void> _loadPatientProfile() async {
    final repo = widget.patientRepository ?? widget.orchestrator.patientRepository;
    final profile = await repo?.getActivePatientProfile();
    if (mounted && profile != null) {
      setState(() {
        _patientProfile = profile;
      });
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final online = await widget.connectivityService.isOnline;
    if (mounted) {
      setState(() {
        _isOnline = online;
      });
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    SarvamSttService.instance.cancel();
    SarvamTtsService.instance.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleMicPressed() async {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final stt = SarvamSttService.instance;
    final currentStatus = stt.statusNotifier.value;

    if (currentStatus.isListening) {
      final transcribedText = await stt.stopAndTranscribe(
        languageCode: langProvider.currentLanguageCode,
      );
      if (mounted && transcribedText != null && transcribedText.trim().isNotEmpty) {
        setState(() {
          _textController.text = transcribedText.trim();
        });
        _sendMessage();
      }
    } else if (currentStatus.isTranscribing) {
      return;
    } else {
      // Stop any audio readout before listening to the patient
      SarvamTtsService.instance.stop();

      final started = await stt.startListening(
        languageCode: langProvider.currentLanguageCode,
        onPartialResult: (partialText) {
          if (mounted) {
            setState(() {
              _textController.text = partialText;
            });
          }
        },
      );

      if (!started && mounted) {
        final err = stt.statusNotifier.value.errorMessage ?? 'Microphone permission denied';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (presetText == null) {
      _textController.clear();
    }

    setState(() {
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      await widget.orchestrator.handleUserMessage(
        text: text,
        conversationId: widget.conversationId,
        patientId: _patientProfile?.patientId,
        languageCode: langProvider.currentLanguageCode,
        languageName: langProvider.currentLanguage.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Conversation?'),
        content: const Text(
          'Are you sure you want to clear your chat history with MediAssist AI?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SarvamTtsService.instance.stop();
      await widget.storageRepository.deleteConversation(widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF006A6A).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Color(0xFF006A6A),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langProvider.tr('ai_assistant'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isOnline
                          ? 'Online • ${langProvider.currentLanguage.name}'
                          : 'Offline Knowledge Mode',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Audio Stop',
            icon: const Icon(Icons.volume_off_rounded, color: Color(0xFF475569)),
            onPressed: () => SarvamTtsService.instance.stop(),
          ),
          IconButton(
            tooltip: 'Cloud Settings',
            icon: const Icon(Icons.vpn_key_outlined, color: Color(0xFF475569)),
            onPressed: () => ApiKeyDialog.show(
              context,
              cloudClient: widget.cloudLlmClient,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF475569)),
            onSelected: (val) {
              if (val == 'clear') _clearChat();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showEmergencyBanner) _buildEmergencyBanner(),
          if (_patientProfile != null) _buildPatientHeaderCard(_patientProfile!),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: widget.storageRepository.watchMessagesForConversation(widget.conversationId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty && !_isGenerating) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length + (_isGenerating ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return _buildMessageBubble(messages[index]);
                    } else {
                      return _buildGeneratingIndicator();
                    }
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'For severe chest pain or breathing issues, call 112 / 108 immediately.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showEmergencyBanner = false;
              });
            },
            child: const Icon(Icons.close, size: 16, color: Color(0xFF991B1B)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientHeaderCard(PatientProfile p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: Text(
                    p.name.isNotEmpty ? p.name[0] : 'P',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A6A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.bloodGroup,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          if (p.allergies.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Text(
                                '⚠️ Allergy: ${p.allergies.first}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${p.room ?? "IPD Ward 304"} • ${p.doctorName ?? "Dr. Rajesh V. Sharma"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showPatientDetails = !_showPatientDetails;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _showPatientDetails
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showPatientDetails) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              color: const Color(0xFFF8FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.diagnosis != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Diagnosis: ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: p.diagnosis!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.vitals != null) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Baseline Vitals: ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          TextSpan(
                            text: p.vitals!,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (p.prescriptions.isNotEmpty) ...[
                    const Text(
                      'Active Prescriptions:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...p.prescriptions.map(
                      (rx) => Padding(
                        padding: const EdgeInsets.only(left: 6, top: 1),
                        child: Text(
                          '• ${rx.medicine} (${rx.frequency}, ${rx.duration})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF006A6A), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              size: 44,
              color: Color(0xFF006A6A),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'How can I help you today?',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask clinical questions with built-in Allergy Protection & Prescription Guidance. Tap the speaker on any answer to listen with Sarvam Voice.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SUGGESTED QUESTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._suggestions.map((suggestion) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _sendMessage(suggestion),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      size: 16,
                      color: Color(0xFF006A6A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final timeStr =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, right: 8),
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Color(0xFF006A6A),
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF006A6A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FormattedMessageView(
                    text: msg.text,
                    isUser: isUser,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: msg.isSynced
                                ? const Color(0xFFE0F2F1)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            msg.isSynced ? 'Ashwini AI' : 'Offline Assistant',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: msg.isSynced
                                  ? const Color(0xFF006A6A)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sarvam TTS Speaker Button
                        ValueListenableBuilder<TtsPlaybackStatus>(
                          valueListenable: SarvamTtsService.instance.statusNotifier,
                          builder: (context, ttsStatus, _) {
                            final isThisPlaying = ttsStatus.activeMessageId == msg.id.toString() && ttsStatus.isPlaying;
                            final isThisLoading = ttsStatus.activeMessageId == msg.id.toString() && ttsStatus.isLoading;

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                if (isThisPlaying || isThisLoading) {
                                  SarvamTtsService.instance.stop();
                                } else {
                                  final langProvider = Provider.of<LanguageProvider>(context, listen: false);
                                  SarvamTtsService.instance.speak(
                                    text: msg.text,
                                    messageId: msg.id.toString(),
                                    languageCode: langProvider.currentLanguageCode,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isThisPlaying
                                      ? const Color(0xFFE0F2F1)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isThisPlaying ? const Color(0xFF006A6A) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isThisLoading) ...[
                                      const SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text('Loading voice...', style: TextStyle(fontSize: 9, color: Color(0xFF006A6A))),
                                    ] else if (isThisPlaying) ...[
                                      const Icon(Icons.stop_circle_rounded, size: 13, color: Color(0xFF006A6A)),
                                      const SizedBox(width: 3),
                                      const Text('Stop', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF006A6A))),
                                    ] else ...[
                                      const Icon(Icons.volume_up_rounded, size: 13, color: Color(0xFF475569)),
                                      const SizedBox(width: 3),
                                      const Text('Listen', style: TextStyle(fontSize: 9, color: Color(0xFF475569))),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 4, left: 8),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF006A6A).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF006A6A),
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneratingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medical_services_rounded,
              color: Color(0xFF006A6A),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Reviewing medical records & guidelines...',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ValueListenableBuilder<SttStatus>(
          valueListenable: SarvamSttService.instance.statusNotifier,
          builder: (context, sttStatus, _) {
            final isListening = sttStatus.isListening;
            final isTranscribing = sttStatus.isTranscribing;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isListening)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listening in ${langProvider.currentLanguage.name}... Tap mic when done',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isTranscribing)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF006A6A).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Transcribing speech with Sarvam AI...',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF006A6A),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isListening ? const Color(0xFFFFF1F2) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isListening ? Colors.red.shade300 : Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: isListening
                                ? 'Speak now in ${langProvider.currentLanguage.name}...'
                                : 'Ask MediAssist (e.g. Can I take Amoxicillin?)...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: isListening ? Colors.red.shade400 : const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sarvam STT Microphone Button
                    Container(
                      decoration: BoxDecoration(
                        color: isListening
                            ? Colors.red
                            : const Color(0xFF006A6A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: isTranscribing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006A6A)),
                                ),
                              )
                            : Icon(
                                isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                color: isListening ? Colors.white : const Color(0xFF006A6A),
                                size: 20,
                              ),
                        tooltip: isListening ? 'Finish speaking' : 'Speak to MediAssist',
                        onPressed: _isGenerating || isTranscribing ? null : _handleMicPressed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Send Button
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF006A6A),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: _isGenerating || isListening ? null : () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
