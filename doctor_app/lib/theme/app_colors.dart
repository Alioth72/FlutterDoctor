import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (Purple Theme)
  static const Color primary = Color(0xFF7C3AED);       // Primary Purple: Main brand color, CTAs, active states
  static const Color primaryDark = Color(0xFF4C1D95);   // Deep Purple: Hover states, emphasis, selected items
  static const Color primaryLight = Color(0xFFEDE9FE);  // Light Purple: Selected backgrounds, badges, highlights
  static const Color background = Color(0xFFF5F3FF);    // App Background: Overall app background, page backgrounds
  static const Color secondary = Color(0xFFA78BFA);     // Soft Purple Accent

  // Typography (Text Colors)
  static const Color headingText = Color(0xFF111827);   // Heading / Primary Text: Titles, important information
  static const Color darkText = Color(0xFF111827);
  static const Color textPrimary = Color(0xFF111827);      // Alias for Heading / Primary Text
  static const Color bodyText = Color(0xFF374151);      // Body Text: Main content, body text
  static const Color muted = Color(0xFF6B7280);         // Secondary / Muted Text: Subtext, descriptions, placeholders
  static const Color disabledText = Color(0xFF9CA3AF);  // Disabled Text: Disabled states, inactive content
  static const Color whiteText = Color(0xFFFFFFFF);     // White Text: Text on colored backgrounds

  // Functional Colors (For Actions & Status)
  static const Color success = Color(0xFF16A34A);       // Success / Book / Confirm: Booking, confirmed, success, available
  static const Color danger = Color(0xFFDC2626);        // Danger / Delete / Emergency: Delete, cancel, error, emergency, critical
  static const Color warning = Color(0xFFEA580C);       // Warning: Warnings, abnormal results, requires attention
  static const Color caution = Color(0xFFCA8A04);       // Caution: Caution, mild warnings, attention needed
  static const Color info = Color(0xFF2563EB);          // Information: Informational items, links, general info
  static const Color aiAssistant = Color(0xFF0891B2);    // AI / Assistant: AI features, insights, assistant, smart suggestions

  // UI Structure & Surfaces
  static const Color border = Color(0xFFE5E7EB);        // Border: Input borders, card borders, dividers
  static const Color divider = Color(0xFFF3F4F6);       // Divider: Section dividers, separators
  static const Color surface = Color(0xFFFFFFFF);       // Card / Surface: Cards, modals, containers
  static const Color elevatedSurface = Color(0xFFFAFAFC); // Elevated Surface: Slightly elevated backgrounds

  // Light containers / backgrounds for status badges & alerts
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color dangerText = Color(0xFF991B1B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningText = Color(0xFF92400E);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successText = Color(0xFF166534);
  static const Color infoBg = Color(0xFFEFF6FF);

  // Gradient Suggestions (For Backgrounds, Buttons, Cards)
  static const LinearGradient gradientPrimaryToDeep = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
  );
  static const LinearGradient gradientPrimaryToAccent = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  );
  static const LinearGradient gradientAccentToCyan = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF22D3EE)],
  );
  static const LinearGradient gradientDeepToCyan = LinearGradient(
    colors: [Color(0xFF4C1D95), Color(0xFF0891B2)],
  );

  // Compatibility aliases
  static const Color dark = darkText;
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentDark = Color(0xFF0891B2);
  static const Color accentLight = Color(0xFFCFFAFE);
}

