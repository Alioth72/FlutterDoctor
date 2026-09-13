import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/health_profile.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/health_profile_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/location_selection_sheet.dart';
import '../../widgets/patient_action_sheets.dart';
import '../family/family_data_screen.dart';
import '../signup_screen.dart';
import '../../widgets/dynamic_translated_text.dart';

/// Premium, appealing Personal Health Profile Dashboard for Ashwini Patient App.
/// Features a rich hero header, digital ABHA health pass, health vitals,
/// offline visit QRs shortcut, family sync, and full profile editing.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _remindersEnabled = true;

  Future<void> _handleLogout(BuildContext context) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.tr('logout_confirm_title'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          lang.tr('logout_confirm_sub'),
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.tr('cancel_btn'), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.tr('logout_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      final provider = Provider.of<HealthProfileProvider>(context, listen: false);
      await provider.clearProfile();

      try {
        final apptProvider = Provider.of<AppointmentProvider>(context, listen: false);
        await apptProvider.clearAllAppointments();
      } catch (_) {}

      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignupScreen()),
        (route) => false,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF7C3AED),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, HealthProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    final ageController = TextEditingController(text: profile.age.toString());
    String selectedGender = profile.gender;
    String selectedResidence = profile.residenceType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Edit Personal Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Full Name
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF7C3AED)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Age & Gender Row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Age',
                            prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF7C3AED)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedGender,
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => selectedGender = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Area / Residence
                  DropdownButtonFormField<String>(
                    initialValue: selectedResidence,
                    decoration: InputDecoration(
                      labelText: 'Area / Residence Type',
                      prefixIcon: const Icon(Icons.home_work_outlined, color: Color(0xFF7C3AED)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Urban', child: Text('Urban (City / Municipality)')),
                      DropdownMenuItem(value: 'Rural', child: Text('Rural (Panchayat / Village)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedResidence = val);
                    },
                  ),
                  const SizedBox(height: 22),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      final updatedAge = int.tryParse(ageController.text.trim()) ?? profile.age;
                      final updatedName = nameController.text.trim().isEmpty ? profile.name : nameController.text.trim();

                      final updatedProfile = profile.copyWith(
                        name: updatedName,
                        age: updatedAge,
                        gender: selectedGender,
                        residenceType: selectedResidence,
                      );

                      final provider = Provider.of<HealthProfileProvider>(context, listen: false);
                      await provider.updateProfile(updatedProfile);

                      if (ctx.mounted) Navigator.pop(ctx);

                      HapticFeedback.heavyImpact();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully!'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDigitalQrPassModal(BuildContext context, HealthProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Color(0xFF7C3AED), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Patient Digital Health Pass',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 130,
                          color: const Color(0xFF4C1D95).withValues(alpha: 0.85),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.local_hospital_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  DynamicTranslatedText(
                    text: profile?.name ?? 'Patient',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      profile?.patientId ?? 'ASH-PT-1001',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan for instant doctor OPD check-in & consultation records synchronization.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOfflineVisitsQrModal(BuildContext context) {
    final visits = [
      {'id': 'VISIT-2026-0814', 'doctor': 'Dr. Ananya Sharma', 'dept': 'Cardiology', 'date': '14 Aug 2026', 'diag': 'Hypertension Review'},
      {'id': 'VISIT-2026-0722', 'doctor': 'Dr. Rajesh Verma', 'dept': 'General Medicine', 'date': '22 Jul 2026', 'diag': 'Seasonal Viral Fever'},
      {'id': 'VISIT-2026-0610', 'doctor': 'Dr. Meenakshi Sundaram', 'dept': 'Orthopedics', 'date': '10 Jun 2026', 'diag': 'Right Knee Arthralgia'},
      {'id': 'VISIT-2026-0418', 'doctor': 'Dr. Rohan Mehra', 'dept': 'Dermatology', 'date': '18 Apr 2026', 'diag': 'Contact Dermatitis'},
      {'id': 'VISIT-2026-0205', 'doctor': 'Dr. Ananya Sharma', 'dept': 'Cardiology', 'date': '05 Feb 2026', 'diag': 'Routine Health Screening'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7C3AED), size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last 5 Doctor Consultation QRs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                      ),
                      Text(
                        'Offline scannable consultation passes',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: visits.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final v = visits[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, size: 44, color: Color(0xFF7C3AED)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v['doctor']!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E1B4B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${v['dept']} • ${v['date']}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B21A8), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Dx: ${v['diag']}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final profileProvider = Provider.of<HealthProfileProvider>(context);
    final profile = profileProvider.profile;

    final name = profile?.name ?? 'Patient';
    final age = profile?.age ?? 28;
    final gender = profile?.gender ?? 'Other';
    final phone = profile?.phoneNumber ?? '';
    final mrn = profile?.tier2Data?['medical_record_number'] as String? ?? profile?.patientId ?? 'ASH-PT-1001';
    final patientId = mrn;
    final residence = profile?.residenceType ?? 'Rural';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 36.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. HERO PROFILE CARD
          _buildHeroProfileCard(
            profile: profile,
            name: name,
            phone: phone,
            patientId: patientId,
          ),
          const SizedBox(height: 16),

          // 2. DIGITAL HEALTH SMART PASS (ABHA CARD)
          _buildAbhaSmartPassCard(
            name: name,
            patientId: patientId,
            profile: profile,
          ),
          const SizedBox(height: 16),

          // 3. HEALTH VITALS & QUICK STATS ROW
          _buildVitalsRow(context, profileProvider),
          const SizedBox(height: 16),

          // 4. PERSONAL & DEMOGRAPHIC DETAILS
          _buildPersonalDetailsCard(
            profile: profile,
            name: name,
            age: age,
            gender: gender,
            phone: phone,
            residence: residence,
            profileProvider: profileProvider,
          ),
          const SizedBox(height: 16),

          // 5. QUICK HEALTHCARE SHORTCUTS
          _buildQuickShortcutsCard(context),
          const SizedBox(height: 16),

          // 6. PREFERENCES & SECURITY
          _buildPreferencesCard(context),
          const SizedBox(height: 24),

          // 7. LOGOUT BUTTON
          _buildLogoutButton(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. HERO PROFILE CARD
  // =========================================================================
  Widget _buildHeroProfileCard({
    required HealthProfile? profile,
    required String name,
    required String phone,
    required String patientId,
  }) {
    // Generate initials
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C3AED), // Luminous Royal Purple
            Color(0xFF6D28D9), // Deep Royal Purple
            Color(0xFF5B21B6), // Midnight Purple
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with glowing border and verified badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        initials.isNotEmpty ? initials : 'PT',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 20,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Name, Phone & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DynamicTranslatedText(
                      text: name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+91 $phone',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.90),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Patient ID Chip with Copy button
                    InkWell(
                      onTap: () => _copyToClipboard(patientId, 'Patient ID'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              patientId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Quick Action Bar inside Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeroQuickBtn(
                    icon: Icons.qr_code_rounded,
                    label: Provider.of<LanguageProvider>(context, listen: false).tr('digital_qr'),
                    onTap: () => _showDigitalQrPassModal(context, profile),
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.25)),
                Expanded(
                  child: _buildHeroQuickBtn(
                    icon: Icons.edit_rounded,
                    label: Provider.of<LanguageProvider>(context, listen: false).tr('edit_profile'),
                    onTap: () {
                      if (profile != null) _showEditProfileSheet(context, profile);
                    },
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.25)),
                Expanded(
                  child: _buildHeroQuickBtn(
                    icon: Icons.history_edu_rounded,
                    label: Provider.of<LanguageProvider>(context, listen: false).tr('offline_qrs'),
                    onTap: () => _showOfflineVisitsQrModal(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroQuickBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. DIGITAL HEALTH SMART PASS (ABHA CARD)
  // =========================================================================
  Widget _buildAbhaSmartPassCard({
    required String name,
    required String patientId,
    required HealthProfile? profile,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4C1D95), // Deep Violet
            Color(0xFF312E81), // Indigo
            Color(0xFF1E1B4B), // Midnight Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, color: Color(0xFFA78BFA), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        Provider.of<LanguageProvider>(context, listen: false).tr('digital_id_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDDD6FE),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF10B981)),
                    const SizedBox(width: 3),
                    Text(
                      Provider.of<LanguageProvider>(context, listen: false).tr('active_status'),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Microchip & ABHA number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Provider.of<LanguageProvider>(context, listen: false).tr('abha_id_label'),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () => _copyToClipboard('91-8765-0123-4567', 'ABHA ID'),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '91-8765-0123-4567',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.copy_rounded, size: 13, color: Color(0xFFA78BFA)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showDigitalQrPassModal(context, profile),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        Provider.of<LanguageProvider>(context, listen: false).tr('view_qr'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. HEALTH VITALS & QUICK STATS ROW
  // =========================================================================
  Widget _buildVitalsRow(BuildContext context, HealthProfileProvider provider) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFFE11D48),
            bgColor: const Color(0xFFFFF1F2),
            value: 'O+',
            label: lang.tr('blood_group_label'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.monitor_weight_outlined,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFF0F9FF),
            value: '68 kg',
            label: '${lang.tr('weight_label')} (22.2)',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.health_and_safety_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            value: lang.tr('eligible_label'),
            label: lang.tr('govt_schemes_label'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyDataScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: _buildMetricCard(
              icon: Icons.family_restroom_rounded,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              value: '${provider.familyMembers.length}',
              label: lang.tr('family_sync_label'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. PERSONAL & DEMOGRAPHIC DETAILS CARD
  // =========================================================================
  Widget _buildPersonalDetailsCard({
    required HealthProfile? profile,
    required String name,
    required int age,
    required String gender,
    required String phone,
    required String residence,
    required HealthProfileProvider profileProvider,
  }) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.badge_rounded, color: Color(0xFF7C3AED), size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        lang.tr('personal_details_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (profile != null) _showEditProfileSheet(context, profile);
                },
                child: Text(
                  lang.tr('edit_btn'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),

          _buildDetailRow(
            icon: Icons.person_outline_rounded,
            label: lang.tr('full_name_label'),
            value: name,
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.cake_outlined,
            label: lang.tr('age_dob_label'),
            value: '$age (1998)',
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: gender == 'Female' ? Icons.female_rounded : Icons.male_rounded,
            label: lang.tr('gender_label'),
            value: gender == 'Female'
                ? lang.tr('gender_female')
                : (gender == 'Male' ? lang.tr('gender_male') : lang.tr('gender_other')),
          ),
          const SizedBox(height: 12),

          _buildDetailRow(
            icon: Icons.phone_outlined,
            label: lang.tr('mobile_phone_label'),
            value: '+91 $phone',
          ),
          const SizedBox(height: 12),

          // Interactive Area / Residence Row with 1-tap toggle
          InkWell(
            onTap: () async {
              if (profile != null) {
                final newArea = profile.residenceType == 'Rural' ? 'Urban' : 'Rural';
                final updated = profile.copyWith(residenceType: newArea);
                await profileProvider.updateProfile(updated);
                HapticFeedback.selectionClick();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.home_work_outlined, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            lang.tr('area_residence_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Text(
                          residence == 'Rural' ? lang.tr('area_rural') : lang.tr('area_urban'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF7C3AED)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hospital Hub Selector Row
          InkWell(
            onTap: () => LocationSelectionSheet.show(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            lang.tr('city_location_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: DynamicTranslatedText(
                          text: profileProvider.currentLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_location_alt_rounded, size: 15, color: Color(0xFF7C3AED)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        DynamicTranslatedText(
          text: value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 5. QUICK HEALTHCARE SHORTCUTS CARD
  // =========================================================================
  Widget _buildQuickShortcutsCard(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared_rounded, color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.tr('healthcare_records_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),

          // 1. Last 5 Doctor Visits
          _buildShortcutTile(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: lang.tr('offline_passes_title'),
            subtitle: lang.tr('offline_passes_sub'),
            onTap: () => _showOfflineVisitsQrModal(context),
          ),
          const SizedBox(height: 8),

          // 2. Family Members Sync
          _buildShortcutTile(
            icon: Icons.family_restroom_rounded,
            iconColor: const Color(0xFF0284C7),
            title: lang.tr('family_members_title'),
            subtitle: lang.tr('family_members_sub'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyDataScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 6. PREFERENCES & SYSTEM CARD
  // =========================================================================
  Widget _buildPreferencesCard(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.tr('preferences_title'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),

          // Language Switcher
          InkWell(
            onTap: () => PatientActionSheets.showLanguageSelector(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.translate_rounded, size: 18, color: Color(0xFF64748B)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            lang.tr('app_language'),
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.currentLanguage.nativeName,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF7C3AED)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Medicine Reminders Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.tr('med_timers_alerts'),
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: _remindersEnabled,
                activeTrackColor: const Color(0xFF7C3AED),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _remindersEnabled = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 7. LOGOUT BUTTON
  // =========================================================================
  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () => _handleLogout(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECDD3), width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Provider.of<LanguageProvider>(context, listen: false).tr('logout_btn'),
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
