import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HrxQrWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;
  final EdgeInsets padding;
  final Widget? embeddedCenterWidget;

  const HrxQrWidget({
    super.key,
    required this.data,
    required this.size,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(8),
    this.embeddedCenterWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      padding: padding,
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
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
          ),
          if (embeddedCenterWidget != null) embeddedCenterWidget!,
        ],
      ),
    );
  }
}
