import 'package:flutter/material.dart';

/// Renders chat messages with rich formatting:
/// - Strips raw markdown `**` and renders clean bold text
/// - Formats headers (`# `, `## `, or standalone `**Title**`) with distinct typography
/// - Converts `- `, `* `, `• ` into properly indented, aligned bullet rows
/// - Converts `1. `, `2. ` into numbered lists
/// - Replaces ASCII arrows `->` or `-->` with typographic `→`
/// - Renders medical safety disclaimers in a clean, reassuring healthcare card
class FormattedMessageView extends StatelessWidget {
  final String text;
  final bool isUser;

  const FormattedMessageView({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final rawLines = text.split('\n');
    final List<Widget> blockWidgets = [];

    final baseTextColor = isUser ? Colors.white : const Color(0xFF1E293B);
    final boldTextColor = isUser ? Colors.white : const Color(0xFF0F172A);
    final headingColor = isUser ? Colors.white : const Color(0xFF005656);
    final bulletColor = isUser ? Colors.white70 : const Color(0xFF00796B);

    final baseStyle = TextStyle(
      fontSize: 14.5,
      color: baseTextColor,
      height: 1.45,
    );

    int i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i].trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // Space between paragraphs
        blockWidgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      // 1. Heading checks: markdown #, ##, ### or standalone line wrapped in **...**
      final markdownHeadingMatch = RegExp(r'^#{1,4}\s+(.*)$').firstMatch(trimmed);

      // Check if line is purely bold heading (with optional trailing : or .)
      String testHeading = trimmed;
      if (testHeading.endsWith(':') || testHeading.endsWith('.')) {
        testHeading = testHeading.substring(0, testHeading.length - 1).trim();
      }
      final isStandaloneBoldHeading = (trimmed.startsWith('**') &&
              trimmed.endsWith('**') &&
              trimmed.length > 4 &&
              !trimmed.substring(2, trimmed.length - 2).contains('**')) ||
          (testHeading.startsWith('**') &&
              testHeading.endsWith('**') &&
              testHeading.length > 4 &&
              !testHeading.substring(2, testHeading.length - 2).contains('**'));

      if (markdownHeadingMatch != null || isStandaloneBoldHeading) {
        String headingContent;
        if (markdownHeadingMatch != null) {
          headingContent = markdownHeadingMatch.group(1) ?? '';
        } else if (testHeading.startsWith('**') && testHeading.endsWith('**')) {
          headingContent = testHeading.substring(2, testHeading.length - 2).trim();
        } else {
          headingContent = trimmed.substring(2, trimmed.length - 2).trim();
        }

        // Remove trailing period from headings/subheadings
        headingContent = headingContent.replaceAll(RegExp(r'\.+$'), '').trim();

        blockWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              headingContent,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: headingColor,
                height: 1.35,
                letterSpacing: -0.2,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // 2. Bullet Point check (- item, * item, • item, + item)
      final bulletMatch = RegExp(r'^\s*[-*•+]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final bulletContent = (bulletMatch.group(1) ?? '').trim();

        // Check if the bullet content is purely a bold subheading
        // e.g. "- **Lifestyle habits**", "- **Health conditions:**", "- **Family history.**"
        String testBulletHeading = bulletContent;
        if (testBulletHeading.endsWith(':') || testBulletHeading.endsWith('.')) {
          testBulletHeading =
              testBulletHeading.substring(0, testBulletHeading.length - 1).trim();
        }

        final isBoldSubheading = (bulletContent.startsWith('**') &&
                bulletContent.endsWith('**') &&
                bulletContent.length > 4 &&
                !bulletContent.substring(2, bulletContent.length - 2).contains('**')) ||
            (testBulletHeading.startsWith('**') &&
                testBulletHeading.endsWith('**') &&
                testBulletHeading.length > 4 &&
                !testBulletHeading.substring(2, testBulletHeading.length - 2).contains('**'));

        if (isBoldSubheading) {
          // Pure bold subheading: do NOT add bullet dot, and strip trailing period
          String subheadingText;
          if (testBulletHeading.startsWith('**') && testBulletHeading.endsWith('**')) {
            subheadingText =
                testBulletHeading.substring(2, testBulletHeading.length - 2).trim();
          } else {
            subheadingText =
                bulletContent.substring(2, bulletContent.length - 2).trim();
          }
          // Remove trailing period from subheading
          subheadingText = subheadingText.replaceAll(RegExp(r'\.+$'), '').trim();

          blockWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 3),
              child: Text(
                subheadingText,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          );
          i++;
          continue;
        }

        // Standard bullet point: keep bullet dot
        blockWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 9, left: 2),
                  width: 5.5,
                  height: 5.5,
                  decoration: BoxDecoration(
                    color: bulletColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        bulletContent,
                        isUser: isUser,
                        baseStyle: baseStyle,
                        boldColor: boldTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 3. Numbered List check (1. item, 2. item)
      final numberMatch = RegExp(r'^\s*(\d+)[\.\)]\s+(.*)$').firstMatch(line);
      if (numberMatch != null) {
        final numberPrefix = numberMatch.group(1) ?? '1';
        final numberContent = (numberMatch.group(2) ?? '').trim();

        // Check if numberContent is purely bold subheading
        String testNumberHeading = numberContent;
        if (testNumberHeading.endsWith(':') || testNumberHeading.endsWith('.')) {
          testNumberHeading =
              testNumberHeading.substring(0, testNumberHeading.length - 1).trim();
        }

        final isBoldNumberHeading = (numberContent.startsWith('**') &&
                numberContent.endsWith('**') &&
                numberContent.length > 4 &&
                !numberContent.substring(2, numberContent.length - 2).contains('**')) ||
            (testNumberHeading.startsWith('**') &&
                testNumberHeading.endsWith('**') &&
                testNumberHeading.length > 4 &&
                !testNumberHeading.substring(2, testNumberHeading.length - 2).contains('**'));

        if (isBoldNumberHeading) {
          String subheadingText;
          if (testNumberHeading.startsWith('**') && testNumberHeading.endsWith('**')) {
            subheadingText =
                testNumberHeading.substring(2, testNumberHeading.length - 2).trim();
          } else {
            subheadingText =
                numberContent.substring(2, numberContent.length - 2).trim();
          }
          subheadingText = subheadingText.replaceAll(RegExp(r'\.+$'), '').trim();

          blockWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 3),
              child: Text(
                '$numberPrefix. $subheadingText',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                  height: 1.35,
                ),
              ),
            ),
          );
          i++;
          continue;
        }

        blockWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$numberPrefix.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isUser ? Colors.white : const Color(0xFF00796B),
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        numberContent,
                        isUser: isUser,
                        baseStyle: baseStyle,
                        boldColor: boldTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. Clinical Allergy / Urgent Safety Alert box
      final lower = trimmed.toLowerCase();
      final isAllergyAlert = !isUser &&
          (lower.contains('allergy alert') ||
              lower.contains('allergy warning') ||
              lower.startsWith('⚠️') ||
              lower.startsWith('warning:'));

      if (isAllergyAlert) {
        blockWidgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        trimmed,
                        isUser: isUser,
                        baseStyle: baseStyle.copyWith(
                          fontSize: 13.5,
                          color: const Color(0xFF991B1B),
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                        boldColor: const Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Standalone Healthcare Disclaimer / Reassurance box
      final isDisclaimer = !isUser &&
          (lower.startsWith('disclaimer:') ||
              lower.startsWith('note:') ||
              lower.startsWith('please note:') ||
              (lower.contains('consult a qualified') && lower.contains('doctor')) ||
              (lower.contains('consult a doctor') && trimmed.length < 160));

      if (isDisclaimer) {
        String cleanDisclaimer = trimmed;
        if (lower.startsWith('disclaimer:')) {
          cleanDisclaimer = cleanDisclaimer.substring(11).trim();
        } else if (lower.startsWith('note:')) {
          cleanDisclaimer = cleanDisclaimer.substring(5).trim();
        }

        blockWidgets.add(
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFCCFBF1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 8),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    size: 16,
                    color: Color(0xFF00796B),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        cleanDisclaimer,
                        isUser: isUser,
                        baseStyle: baseStyle.copyWith(
                          fontSize: 12.5,
                          color: const Color(0xFF065F46),
                          height: 1.38,
                          fontWeight: FontWeight.w500,
                        ),
                        boldColor: const Color(0xFF064E3B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Standard line / paragraph
      blockWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(
            TextSpan(
              children: _parseInlineSpans(
                trimmed,
                isUser: isUser,
                baseStyle: baseStyle,
                boldColor: boldTextColor,
              ),
            ),
          ),
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  static List<InlineSpan> _parseInlineSpans(
    String text, {
    required bool isUser,
    required TextStyle baseStyle,
    required Color boldColor,
  }) {
    // Convert ASCII arrows to typography arrow
    final cleanText = text.replaceAll('-->', '→').replaceAll('->', '→');

    final List<InlineSpan> spans = [];
    // Regex for:
    // group 1 & 2: **bold**
    // group 3 & 4: *italic*
    // group 5 & 6: `code`
    final tokenRegex = RegExp(r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`([^`]+)`)');
    int lastEnd = 0;

    for (final match in tokenRegex.allMatches(cleanText)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: cleanText.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      if (match.group(2) != null) {
        // Bold (**text**)
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: boldColor,
          ),
        ));
      } else if (match.group(4) != null) {
        // Italic (*text*)
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(6) != null) {
        // Code (`code`)
        spans.add(TextSpan(
          text: match.group(6),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            fontSize: (baseStyle.fontSize ?? 14.5) * 0.9,
            backgroundColor: isUser ? Colors.white24 : const Color(0xFFF1F5F9),
          ),
        ));
      }

      lastEnd = match.end;
    }

    if (lastEnd < cleanText.length) {
      spans.add(TextSpan(
        text: cleanText.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }
}
