import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/localization/sarvam_translation_service.dart';
import 'speakable.dart';

/// Renders dynamically translated text using Sarvam AI and local healthcare catalog.
/// Immediately renders synchronous cache if available to guarantee zero flicker.
class DynamicTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool fitScaleDown;
  final String? prefix;
  final bool enableHoldToSpeak;

  const DynamicTranslatedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.fitScaleDown = false,
    this.prefix,
    this.enableHoldToSpeak = true,
  });

  @override
  State<DynamicTranslatedText> createState() => _DynamicTranslatedTextState();
}

class _DynamicTranslatedTextState extends State<DynamicTranslatedText> {
  String? _translatedText;
  String? _lastText;
  String? _lastLangCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndTranslate();
  }

  @override
  void didUpdateWidget(covariant DynamicTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _checkAndTranslate();
    }
  }

  void _checkAndTranslate() {
    final langProvider = Provider.of<LanguageProvider>(context);
    final targetLang = langProvider.currentLanguageCode;

    if (widget.text.trim().isEmpty || targetLang == 'en' || targetLang == 'en-IN') {
      _translatedText = widget.text;
      _lastText = widget.text;
      _lastLangCode = targetLang;
      return;
    }

    if (_lastText == widget.text && _lastLangCode == targetLang && _translatedText != null) {
      return;
    }

    _lastText = widget.text;
    _lastLangCode = targetLang;

    // 1. Check synchronous cache first
    final cached = SarvamTranslationService.getCached(widget.text, targetLang);
    if (cached != null) {
      _translatedText = cached;
      return;
    }

    // 2. Otherwise trigger asynchronous translation
    _translatedText = widget.text; // show original while translating
    SarvamTranslationService.translate(
      widget.text,
      targetLanguageCode: targetLang,
    ).then((result) {
      if (mounted && _lastText == widget.text && _lastLangCode == targetLang) {
        setState(() {
          _translatedText = result;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final currentLang = langProvider.currentLanguageCode;

    // Re-check cache in build to guarantee instant response on language change
    String displayText = _translatedText ?? widget.text;
    if (currentLang != 'en' && currentLang != 'en-IN') {
      final cached = SarvamTranslationService.getCached(widget.text, currentLang);
      if (cached != null) {
        displayText = cached;
      } else if (_lastLangCode != currentLang || _lastText != widget.text) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndTranslate();
        });
      }
    }

    if (widget.prefix != null) {
      displayText = '${widget.prefix}$displayText';
    }

    final textWidget = Text(
      displayText,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );

    final Widget resultWidget;
    if (widget.fitScaleDown) {
      resultWidget = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: widget.textAlign == TextAlign.center
            ? Alignment.center
            : Alignment.centerLeft,
        child: textWidget,
      );
    } else {
      resultWidget = textWidget;
    }

    if (widget.enableHoldToSpeak && displayText.trim().isNotEmpty) {
      return Speakable(
        text: displayText,
        languageCode: currentLang,
        child: resultWidget,
      );
    }

    return resultWidget;
  }
}
