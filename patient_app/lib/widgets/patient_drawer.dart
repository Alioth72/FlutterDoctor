import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/health_profile.dart';
import '../providers/health_profile_provider.dart';
import '../providers/language_provider.dart';
import '../screens/family/family_data_screen.dart';
import '../screens/signup_screen.dart';
import '../theme/app_colors.dart';
import 'location_selection_sheet.dart';
import 'patient_action_sheets.dart';
import 'dynamic_translated_text.dart';
import 'patient_qr_sheets.dart';

/// Executive Patient Drawer redesign matching the Doctor App sidebar aesthetic.
class PatientDrawer extends StatelessWidget {
  const PatientDrawer({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(lang.tr('logout_confirm_title')),
          ],
        ),
        content: Text(
          lang.tr('logout_confirm_sub'),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.tr('cancel_btn')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.tr('logout_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      final provider = Provider.of<HealthProfileProvider>(context, listen: false);
      await provider.clearProfile();

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignupScreen()),
        (route) => false,
      );
    }
  }

  void _showPatientQrDialog(BuildContext context, HealthProfile? profile) {
    PatientQrSheets.showPatientIdentityQrModal(context, profile);
  }

  void _showOfflineVisitsQrModal(BuildContext context, HealthProfile? profile) {
    PatientQrSheets.showOfflineVisitsQrModal(context, profile);
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<HealthProfileProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final currentLang = langProvider.currentLanguage;
    final profile = profileProvider.profile;

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Executive Gradient Header matching Doctor App
          Container(
            padding: const EdgeInsets.fromLTRB(18, 42, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: "View QR" Button & Close (X) Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // "View QR" Button (Digital Health QR)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPatientQrDialog(context, profile),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                color: Color(0xFF7C3AED),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                langProvider.tr('drawer_view_qr'),
                                style: const TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Right Close (X) Button
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close Menu',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Patient Name
                DynamicTranslatedText(
                  text: profile?.name ?? 'Vikram Malhotra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),

                // Patient Phone
                Text(
                  '+91 ${profile?.phoneNumber ?? "9876501234"}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),

                // Enlarged Patient ID Chip (Patient Profile pill removed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ID: ${profile?.patientId ?? "ASH-PT-1234"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Enlarged Active Hospital Center Indicator
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    LocationSelectionSheet.show(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DynamicTranslatedText(
                            text: profile?.location ?? 'New Delhi, Delhi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.yellowAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            langProvider.tr('drawer_change_city'),
                            style: const TextStyle(
                              color: Colors.yellowAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Language Switch Tile
          ListTile(
            leading: const Icon(Icons.translate_rounded, color: Color(0xFF7C3AED)),
            title: Text(langProvider.tr('app_language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text('${currentLang.nativeName} (${currentLang.name})', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Text(
                currentLang.badge,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              PatientActionSheets.showLanguageSelector(context);
            },
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
            indent: 16,
            endIndent: 16,
          ),

          // 3. Offline Visit QRs (Last 5 Visits - Compressed)
          ListTile(
            leading: const Icon(Icons.history_edu_rounded, color: Color(0xFF7C3AED)),
            title: Text(langProvider.tr('offline_passes_title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text(langProvider.tr('offline_passes_sub'), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                'Deflate QR',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showOfflineVisitsQrModal(context, profile);
            },
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE2E8F0),
            indent: 16,
            endIndent: 16,
          ),

          // 4. Drawer Navigation Items (Redundant items removed)
          ListTile(
            leading: const Icon(Icons.family_restroom, color: AppColors.primary),
            title: Text(langProvider.tr('drawer_family_data'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: Text(langProvider.tr('drawer_family_sub'), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyDataScreen()));
            },
          ),

          const Divider(
            height: 20,
            thickness: 1,
            color: Color(0xFFE2E8F0),
            indent: 16,
            endIndent: 16,
          ),

          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: Text(
              langProvider.tr('drawer_logout'),
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }
}
