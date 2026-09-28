import 'package:flutter/material.dart';

/// Reusable widget to render real rPPG Blood Volume Pulse (BVP) waveforms.
///
/// Plots a continuous series of normalized optical signal points received from
/// the on-device ME-rPPG neural inference engine.
class RppgWaveformGraph extends StatelessWidget {
  final List<double> waveform;
  final double? bpm;
  final DateTime? measuredAt;
  final String source;
  final double height;
  final Color primaryColor;
  final bool showHeader;

  const RppgWaveformGraph({
    super.key,
    required this.waveform,
    this.bpm,
    this.measuredAt,
    this.source = 'Camera Vitals',
    this.height = 140,
    this.primaryColor = const Color(0xFFE11D48),
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = waveform.length >= 5;

    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark medical telemetry background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasData ? primaryColor : Colors.grey,
                        boxShadow: hasData
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LIVE PULSE WAVEFORM',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: hasData
                ? CustomPaint(
                    painter: _WaveformPainter(
                      points: waveform,
                      lineColor: primaryColor,
                    ),
                    child: Container(),
                  )
                : Center(
                    child: Text(
                      'No waveform signal recorded.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
          if (measuredAt != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Source: $source',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(measuredAt!),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;

  _WaveformPainter({
    required this.points,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Draw light grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 0.8;

    const vDivisions = 6;
    for (int i = 1; i < vDivisions; i++) {
      final x = size.width * (i / vDivisions);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    const hDivisions = 3;
    for (int i = 1; i < hDivisions; i++) {
      final y = size.height * (i / hDivisions);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Determine min and max for normalization
    double minVal = points.first;
    double maxVal = points.first;
    for (final p in points) {
      if (p < minVal) minVal = p;
      if (p > maxVal) maxVal = p;
    }
    final range = maxVal - minVal;
    final safeRange = range <= 1e-6 ? 1.0 : range;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (points.length - 1);
    final topPadding = size.height * 0.12;
    final usableHeight = size.height * 0.76;

    for (int i = 0; i < points.length; i++) {
      final norm = (points[i] - minVal) / safeRange;
      // Invert Y because canvas (0,0) is top-left
      final y = size.height - (topPadding + norm * usableHeight);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Gradient fill under the pulse line
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Glowing main pulse line
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
