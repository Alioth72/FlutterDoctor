import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/health_profile.dart';
import '../providers/health_profile_provider.dart';
import '../screens/family/family_data_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/tabs/profile_tab.dart';
import '../theme/app_colors.dart';
import 'location_selection_sheet.dart';

/// Executive Patient Drawer redesign matching the Doctor App sidebar aesthetic.
class PatientDrawer extends StatelessWidget {
  const PatientDrawer({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Logout?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your Ashwini patient account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
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
                      'Patient Digital Health QR',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
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
                  Text(
                    profile?.name ?? 'Vikram Malhotra',
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ID: ${profile?.patientId ?? "ASH-PT-1234"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+91 ${profile?.phoneNumber ?? "9876501234"} • ABHA Verified',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Show this QR code at hospital reception desk or to your doctor for instantaneous check-in and records lookup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            // Button for offline QRs where last 5 visits to doctor are stored
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showOfflineVisitsQrModal(context, profile);
              },
              icon: const Icon(Icons.history_edu_rounded, size: 20, color: Color(0xFF7C3AED)),
              label: const Text(
                'Offline Visit QRs (Last 5 Visits)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                backgroundColor: const Color(0xFFF5F3FF),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Done'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the 5 last offline QRs corresponding to the last 5 doctor visits.
  void _showOfflineVisitsQrModal(BuildContext context, HealthProfile? profile) {
    final List<Map<String, dynamic>> last5Visits = [
      {
        'visitId': 'VST-2026-0905',
        'doctor': 'Dr. Ananya Sharma',
        'specialty': 'Cardiology',
        'hospital': 'Apollo Health City, New Delhi',
        'date': '05 Sep 2026',
        'time': '11:30 AM',
        'diagnosis': 'Hypertension & Cardiac Checkup',
        'medication': 'Paracetamol 500mg, Telmisartan 40mg',
        'instructions': 'BP: 128/82 mmHg. Reduce sodium, 30m brisk walk daily.',
        'qrIcon': Icons.favorite_rounded,
        'badgeColor': const Color(0xFFE11D48),
      },
      {
        'visitId': 'VST-2026-0822',
        'doctor': 'Dr. Rajesh Verma',
        'specialty': 'General Medicine',
        'hospital': 'Max Super Specialty Hospital',
        'date': '22 Aug 2026',
        'time': '04:15 PM',
        'diagnosis': 'Acute Viral Fever & Fatigue',
        'medication': 'Azithromycin 500mg, Paracetamol 650mg, ORS',
        'instructions': 'Complete full 3-day course. Drink 3L fluids daily.',
        'qrIcon': Icons.healing_rounded,
        'badgeColor': const Color(0xFF2563EB),
      },
      {
        'visitId': 'VST-2026-0810',
        'doctor': 'Dr. Priya Nair',
        'specialty': 'Dermatology',
        'hospital': 'Skin & Aesthetic Care Clinic',
        'date': '10 Aug 2026',
        'time': '02:00 PM',
        'diagnosis': 'Allergic Contact Dermatitis',
        'medication': 'Cetirizine 10mg, Hydrocortisone Cream 1%',
        'instructions': 'Apply cream twice daily after bathing. Avoid scented soaps.',
        'qrIcon': Icons.spa_rounded,
        'badgeColor': const Color(0xFF0D9488),
      },
      {
        'visitId': 'VST-2026-0728',
        'doctor': 'Dr. Arjun Mehta',
        'specialty': 'Orthopedics',
        'hospital': 'Fortis Bone & Joint Institute',
        'date': '28 Jul 2026',
        'time': '10:45 AM',
        'diagnosis': 'Patellofemoral Strain (Right Knee)',
        'medication': 'Ibuprofen 400mg, Joint Pain Gel',
        'instructions': 'Wear knee brace during long walks. Ice compress 15 mins.',
        'qrIcon': Icons.accessible_rounded,
        'badgeColor': const Color(0xFFD97706),
      },
      {
        'visitId': 'VST-2026-0715',
        'doctor': 'Dr. Kavita Rao',
        'specialty': 'Endocrinology',
        'hospital': 'City Diabetes & Hormone Centre',
        'date': '15 Jul 2026',
        'time': '09:30 AM',
        'diagnosis': 'Routine HbA1c & Glucose Screening',
        'medication': 'Metformin 500mg SR (Post-Dinner)',
        'instructions': 'HbA1c 6.2% (Good control). Repeat test after 3 months.',
        'qrIcon': Icons.bloodtype_rounded,
        'badgeColor': const Color(0xFF7C3AED),
      },
    ];

    int selectedIndex = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final visit = last5Visits[selectedIndex];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 14),

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Doctor Visit QRs',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '5 Last Visits Stored • No Internet Needed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Visit selector tabs (1 to 5)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(last5Visits.length, (i) {
                      final isSelected = i == selectedIndex;
                      final v = last5Visits[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setModalState(() => selectedIndex = i);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  v['qrIcon'] as IconData,
                                  size: 14,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Visit ${i + 1} (${v['date'].toString().split(' ').take(2).join(' ')})',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Scrollable Visit Card Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Main QR Card Container
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                          ),
                          child: Column(
                            children: [
                              // Scannable Offline QR Box
                              Container(
                                width: 155,
                                height: 155,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 132,
                                      color: const Color(0xFF4C1D95).withValues(alpha: 0.9),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: visit['badgeColor'] as Color,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: Icon(
                                        visit['qrIcon'] as IconData,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Doctor Name & Specialty
                              Text(
                                visit['doctor'] as String,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: (visit['badgeColor'] as Color).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      visit['specialty'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: visit['badgeColor'] as Color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${visit['date']} • ${visit['time']}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Visit ID Token Pill with Copy
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: visit['visitId'] as String));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied Visit ID: ${visit['visitId']}'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: const Color(0xFF7C3AED),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Visit ID: ${visit['visitId']}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Clinical Details Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVisitInfoRow(Icons.local_hospital_rounded, 'Clinic / Center', visit['hospital'] as String),
                              const SizedBox(height: 8),
                              _buildVisitInfoRow(Icons.medical_services_outlined, 'Clinical Diagnosis', visit['diagnosis'] as String),
                              const SizedBox(height: 8),
                              _buildVisitInfoRow(Icons.medication_rounded, 'Prescription Stored', visit['medication'] as String),
                              const SizedBox(height: 8),
                              _buildVisitInfoRow(Icons.notes_rounded, 'Doctor Instructions', visit['instructions'] as String),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Offline Notice
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Color(0xFF16A34A), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'This QR code is stored in local flash memory and can be scanned by medical staff without network access.',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          _showPatientQrDialog(context, profile);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back to Main QR'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C3AED),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Done'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisitInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<HealthProfileProvider>(context);
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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                color: Color(0xFF7C3AED),
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'View QR',
                                style: TextStyle(
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
                Text(
                  profile?.name ?? 'Vikram Malhotra',
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
                          child: Text(
                            profile?.location ?? 'New Delhi, Delhi',
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
                          child: const Text(
                            'Change ▾',
                            style: TextStyle(
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

          // 2. Drawer Navigation Items (Redundant items removed)
          ListTile(
            leading: const Icon(Icons.family_restroom, color: AppColors.primary),
            title: const Text('FAMILY DATA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            subtitle: const Text('Sync and link family medical profiles', style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
            title: const Text(
              'Logout',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }
}
