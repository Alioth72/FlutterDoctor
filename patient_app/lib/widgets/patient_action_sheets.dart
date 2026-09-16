import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../services/localization/app_strings.dart';
import 'dynamic_translated_text.dart';
import '../features/chatbot/chatbot_ui.dart';

class PatientActionSheets {
  /// Language Switcher Dialog covering all 22 Official Scheduled Indian Languages + English
  static void showLanguageSelector(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentCode = langProvider.currentLanguageCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allLanguages = AppLanguages.supportedLanguages;
            String searchQuery = '';

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (context, scrollController) {
                return StatefulBuilder(
                  builder: (context, setStateInternal) {
                    final filteredLanguages = allLanguages.where((lang) {
                      final q = searchQuery.toLowerCase().trim();
                      if (q.isEmpty) return true;
                      return lang.name.toLowerCase().contains(q) ||
                          lang.nativeName.toLowerCase().contains(q) ||
                          lang.code.toLowerCase().contains(q);
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag Handle
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.translate_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      langProvider.tr('choose_language'),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      langProvider.tr('official_languages_sub'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                        ),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: TextField(
                              key: const ValueKey('search_language_field'),
                              onChanged: (val) {
                                setStateInternal(() {
                                  searchQuery = val;
                                });
                              },
                              style: const TextStyle(fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: langProvider.tr('search_language'),
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C3AED), size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Language Grid / List
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            itemCount: filteredLanguages.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final lang = filteredLanguages[idx];
                              final isSelected = lang.code == currentCode;

                              return InkWell(
                                key: ValueKey('lang_item_${lang.code}'),
                                onTap: () {
                                  langProvider.setLanguage(lang.code);
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text('${lang.name} (${lang.nativeName}) ${langProvider.tr("activated_msg")}'),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF7C3AED),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFF5F3FF) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(color: const Color(0xFFC4B5FD), width: 1.2)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Badge
                                      Container(
                                        width: 42,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF7C3AED)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          lang.badge,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : const Color(0xFF475569),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Names
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.nativeName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              lang.name,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selected Check Icon
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF7C3AED),
                                          size: 22,
                                        )
                                      else
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Color(0xFFCBD5E1),
                                          size: 14,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Contact Doctor / Tele-consultation Sheet
  static void showContactDoctorSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 30,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.support_agent_rounded, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              lang.tr('contact_doctor_title'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr('contact_doctor_sub'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.tr('connecting_doctor_msg'))),
                      );
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: Text(lang.tr('audio_call_btn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(lang.tr('starting_video_msg'))),
                      );
                    },
                    icon: const Icon(Icons.videocam_rounded),
                    label: Text(lang.tr('video_call_btn')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Voice Assistant Listening Modal
  static void showVoiceAssistant(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.redAccent,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lang.tr('voice_listening_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr('voice_listening_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(lang.tr('cancel_btn')),
            ),
          ],
        ),
      ),
    );
  }

  /// Buy Medicines / Prescription lookup modal
  static void showBuyMedicines(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.medication_rounded, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.tr('central_pharmacy_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              stylusHandwritingEnabled: false,
              decoration: InputDecoration(
                hintText: lang.tr('search_medicine_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Text(lang.tr('generic_medicines_sub'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            _buildMedicineTile('Paracetamol 650mg (Jan Aushadhi)', '₹12 for 10 tabs', 'In Stock', lang),
            _buildMedicineTile('Amoxicillin 500mg', '₹28 for 10 caps', 'In Stock', lang),
            _buildMedicineTile('Metformin 500mg', '₹15 for 10 tabs', 'In Stock', lang),
          ],
        ),
      ),
    );
  }

  static Widget _buildMedicineTile(String name, String price, String status, LanguageProvider lang) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.medical_information_outlined, color: Colors.teal),
      title: DynamicTranslatedText(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(price),
      trailing: FilledButton.tonal(
        onPressed: () {},
        child: Text(lang.tr('add_btn'), style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// AI Assistant Multilingual Chatbot Entry Point
  static void showAiAssistant(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatbotPage(),
      ),
    );
  }

  /// Emergency SOS Sheet
  static void showEmergency(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.emergency_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 14),
            Text(
              lang.tr('emergency_title'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.red),
            ),
            const SizedBox(height: 6),
            Text(
              lang.tr('emergency_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang.tr('sos_dispatched_msg')),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: Text(lang.tr('emergency_call_btn'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
