import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tts/sarvam_tts_service.dart';

/// Floating visual banner displayed when 1-second hold-to-speak voice synthesis is active.
class HoldToSpeakOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _autoDismissTimer;
  static VoidCallback? _ttsStatusListener;

  /// Shows an interactive speech playback pill at the bottom of the screen
  static void show(
    BuildContext context, {
    required String text,
    required String languageCode,
    String? languageName,
  }) {
    // Clear any previous overlay
    dismiss();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _HoldToSpeakPill(
        text: text,
        languageCode: languageCode,
        languageName: languageName,
        onStop: dismiss,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // Listen to TTS playback status to dismiss when playback finishes
    void onStatusChanged() {
      final status = SarvamTtsService.instance.statusNotifier.value;
      if (status.isIdle) {
        _autoDismissTimer?.cancel();
        _autoDismissTimer = Timer(const Duration(milliseconds: 600), () {
          dismiss();
        });
      }
    }

    _ttsStatusListener = onStatusChanged;
    SarvamTtsService.instance.statusNotifier.addListener(onStatusChanged);
  }

  /// Dismisses the currently active speech overlay and stops playback if needed
  static void dismiss({bool stopAudio = false}) {
    if (stopAudio) {
      SarvamTtsService.instance.stop();
    }
    if (_ttsStatusListener != null) {
      SarvamTtsService.instance.statusNotifier.removeListener(_ttsStatusListener!);
      _ttsStatusListener = null;
    }
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _HoldToSpeakPill extends StatefulWidget {
  final String text;
  final String languageCode;
  final String? languageName;
  final VoidCallback onStop;

  const _HoldToSpeakPill({
    required this.text,
    required this.languageCode,
    this.languageName,
    required this.onStop,
  });

  @override
  State<_HoldToSpeakPill> createState() => _HoldToSpeakPillState();
}

class _HoldToSpeakPillState extends State<_HoldToSpeakPill> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cleanText = widget.text.trim().replaceAll('\n', ' ');
    final displaySnippet = cleanText.length > 45 ? '${cleanText.substring(0, 45)}...' : cleanText;
    final langBadge = widget.languageCode.toUpperCase().split('-').first;

    return Positioned(
      bottom: 84, // elevated above bottom navigation bar
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFA78BFA).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Pulsing speaker icon
                AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(
                          alpha: 0.4 + (_animCtrl.value * 0.4),
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),

                // Language badge + Text snippet
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              langBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Reading aloud...',
                            style: TextStyle(
                              color: Color(0xFFDDD6FE),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displaySnippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Stop button
                InkWell(
                  onTap: () {
                    HoldToSpeakOverlay.dismiss(stopAudio: true);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 3),
                        Text(
                          'Stop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
