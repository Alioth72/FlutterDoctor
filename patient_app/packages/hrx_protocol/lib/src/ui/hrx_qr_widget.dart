import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Standard ISO/IEC 18004 QR Code Widget using qr_flutter.
/// Guarantees 100% compliant Reed-Solomon blocks and instant readability
/// on physical camera barcode scanners (ML Kit, ZXing, mobile_scanner).
class HrxQrWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;
  final Widget? embeddedCenterWidget;
  final double centerWidgetSize;
  final EdgeInsets padding;

  const HrxQrWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.foregroundColor = const Color(0xFF1E1B4B),
    this.backgroundColor = Colors.white,
    this.embeddedCenterWidget,
    this.centerWidgetSize = 36,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    final innerSize = (size - padding.horizontal).clamp(20.0, double.infinity);

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: innerSize,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: foregroundColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: foregroundColor,
            ),
            backgroundColor: backgroundColor,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            gapless: false,
          ),
          if (embeddedCenterWidget != null)
            Container(
              width: centerWidgetSize,
              height: centerWidgetSize,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(child: embeddedCenterWidget),
            ),
        ],
      ),
    );
  }
}
