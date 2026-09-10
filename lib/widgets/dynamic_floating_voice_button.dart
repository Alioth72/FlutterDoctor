import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'patient_action_sheets.dart';

/// Clean, responsive Floating AI Voice Assistant Button.
/// Anchored by default at the bottom-right corner.
/// Moves with 1:1 finger tracking when dragged, with zero lag.
/// Designed cleanly with Ashwini Royal Purple theme.
class DynamicFloatingVoiceButton extends StatefulWidget {
  final double? parentWidth;
  final double? parentHeight;

  const DynamicFloatingVoiceButton({
    super.key,
    this.parentWidth,
    this.parentHeight,
  });

  @override
  State<DynamicFloatingVoiceButton> createState() => _DynamicFloatingVoiceButtonState();
}

class _DynamicFloatingVoiceButtonState extends State<DynamicFloatingVoiceButton> {
  // Current user-dragged position (null initially => defaults to bottom-right corner)
  double? _posX;
  double? _posY;

  // Pointer tracking anchors for instantaneous, lag-free 1:1 dragging
  Offset? _dragStartPointerPos;
  Offset? _dragStartButtonPos;
  bool _hasDragged = false;
  DateTime? _lastOpenTime;

  static const double _buttonSize = 58.0;

  void _openVoiceAssistant() {
    final now = DateTime.now();
    if (_lastOpenTime != null && now.difference(_lastOpenTime!).inMilliseconds < 500) {
      return;
    }
    _lastOpenTime = now;
    HapticFeedback.mediumImpact();
    PatientActionSheets.showVoiceAssistant(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Use parent container dimensions if provided, otherwise estimate from screen size
    final availableWidth = widget.parentWidth ?? screenSize.width;
    final availableHeight = widget.parentHeight ?? (screenSize.height - padding.bottom - 160.0);

    // Default position: solidly at bottom-right corner, 24px above bottom nav bar
    final defaultX = availableWidth - _buttonSize - 18.0;
    final defaultY = availableHeight - _buttonSize - 24.0;

    final minX = 12.0;
    final maxX = (availableWidth - _buttonSize - 12.0).clamp(minX, double.infinity);
    final minY = 12.0;
    final maxY = (availableHeight - _buttonSize - 18.0).clamp(minY, double.infinity);

    final currentX = (_posX ?? defaultX).clamp(minX, maxX);
    final currentY = (_posY ?? defaultY).clamp(minY, maxY);

    return Positioned(
      left: currentX,
      top: currentY,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openVoiceAssistant,
        onPanStart: (details) {
          _dragStartPointerPos = details.globalPosition;
          _dragStartButtonPos = Offset(currentX, currentY);
          _hasDragged = false;
        },
        onPanUpdate: (details) {
          if (_dragStartPointerPos == null || _dragStartButtonPos == null) return;
          final delta = details.globalPosition - _dragStartPointerPos!;
          if (delta.distance > 4.0) {
            _hasDragged = true;
          }

          final targetX = _dragStartButtonPos!.dx + delta.dx;
          final targetY = _dragStartButtonPos!.dy + delta.dy;
          final clampedX = targetX.clamp(minX, maxX);
          final clampedY = targetY.clamp(minY, maxY);

          // Re-anchor if clamped at boundaries so moving back responds immediately
          if (targetX != clampedX) {
            _dragStartButtonPos = Offset(clampedX, _dragStartButtonPos!.dy);
            _dragStartPointerPos = Offset(details.globalPosition.dx, _dragStartPointerPos!.dy);
          }
          if (targetY != clampedY) {
            _dragStartButtonPos = Offset(_dragStartButtonPos!.dx, clampedY);
            _dragStartPointerPos = Offset(_dragStartPointerPos!.dx, details.globalPosition.dy);
          }

          setState(() {
            _posX = clampedX;
            _posY = clampedY;
          });
        },
        onPanEnd: (_) {
          if (!_hasDragged) {
            _openVoiceAssistant();
          } else {
            HapticFeedback.lightImpact();
          }
          _dragStartPointerPos = null;
          _dragStartButtonPos = null;
        },
        onPanCancel: () {
          _dragStartPointerPos = null;
          _dragStartButtonPos = null;
        },
        child: Container(
          width: _buttonSize,
          height: _buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8B5CF6), // Bright Violet
                Color(0xFF7C3AED), // Ashwini Primary Royal Purple
                Color(0xFF6D28D9), // Deep Royal Purple
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.42),
                offset: const Offset(0, 6),
                blurRadius: 16,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
