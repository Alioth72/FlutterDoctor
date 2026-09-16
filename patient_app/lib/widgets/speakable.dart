import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/tts/sarvam_tts_service.dart';
import 'hold_to_speak_overlay.dart';

/// Reusable universal wrapper widget that triggers speech synthesis when held for 1 second.
///
/// Works seamlessly on any widget (Buttons, Cards, ListTiles, Plain Text, Scheme cards)
/// without interfering with regular tap events (`onPressed`) or scrolling gestures.
class Speakable extends StatefulWidget {
  final Widget child;

  /// The text to speak when held for 1 second.
  /// If omitted, [Speakable] will inspect [child] if it is a [Text] widget.
  final String? text;

  /// Optional specific language code (e.g. 'hi', 'en', 'bn').
  /// If omitted, defaults to the active language from [LanguageProvider].
  final String? languageCode;

  /// Hold duration required to activate speech. Defaults to exactly 1000ms (1 second).
  final Duration holdDuration;

  /// Whether the hold-to-speak accessibility gesture is enabled.
  final bool enabled;

  /// Optional callback invoked when the 1-second hold triggers speech.
  final VoidCallback? onSpeechTriggered;

  const Speakable({
    super.key,
    required this.child,
    this.text,
    this.languageCode,
    this.holdDuration = const Duration(milliseconds: 1000),
    this.enabled = true,
    this.onSpeechTriggered,
  });

  @override
  State<Speakable> createState() => _SpeakableState();
}

class _SpeakableState extends State<Speakable> {
  Timer? _holdTimer;
  Offset? _startPos;
  bool _hasTriggered = false;

  @override
  void dispose() {
    _cancelHoldTimer();
    super.dispose();
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _startPos = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _hasTriggered = false;
    _startPos = event.position;
    _holdTimer?.cancel();

    _holdTimer = Timer(widget.holdDuration, () {
      if (!mounted) return;
      _hasTriggered = true;
      _triggerHoldToSpeak();
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_startPos != null && !_hasTriggered) {
      final distance = (event.position - _startPos!).distance;
      // If user drags/scrolls > 12 pixels, cancel the hold timer to prevent accidental speech during scroll
      if (distance > 12.0) {
        _cancelHoldTimer();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _cancelHoldTimer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _cancelHoldTimer();
  }

  String? _resolveTextToSpeak() {
    if (widget.text != null && widget.text!.trim().isNotEmpty) {
      return widget.text!.trim();
    }
    if (widget.child is Text) {
      final t = (widget.child as Text).data;
      if (t != null && t.trim().isNotEmpty) return t.trim();
    }
    return null;
  }

  Future<void> _triggerHoldToSpeak() async {
    final textToSpeak = _resolveTextToSpeak();
    if (textToSpeak == null || textToSpeak.isEmpty) return;

    // 1. Tactile haptic feedback
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Resolve active language from LanguageProvider
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final targetLang = widget.languageCode ?? langProvider.currentLanguageCode;
    final currentLangInfo = langProvider.currentLanguage;

    // 3. Show visual indicator pill
    HoldToSpeakOverlay.show(
      context,
      text: textToSpeak,
      languageCode: targetLang,
      languageName: currentLangInfo.name,
    );

    // 4. Trigger optional callback
    widget.onSpeechTriggered?.call();

    // 5. Synthesize speech in the active language via Sarvam TTS (or fallback)
    try {
      await SarvamTtsService.instance.speak(
        text: textToSpeak,
        languageCode: targetLang,
      );
    } catch (e) {
      debugPrint('[Speakable] Speech synthesis error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}

/// Extension for convenient fluent chaining: `myWidget.speakable(text: "...")`
extension SpeakableExtension on Widget {
  Widget speakable({
    String? text,
    String? languageCode,
    Duration holdDuration = const Duration(milliseconds: 1000),
    bool enabled = true,
    VoidCallback? onSpeechTriggered,
  }) {
    return Speakable(
      text: text,
      languageCode: languageCode,
      holdDuration: holdDuration,
      enabled: enabled,
      onSpeechTriggered: onSpeechTriggered,
      child: this,
    );
  }
}
