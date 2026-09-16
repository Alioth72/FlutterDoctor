import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../services/patient_database_service.dart';
import '../../widgets/news_flash_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/health_profile_provider.dart';
import '../../providers/language_provider.dart';
import '../appointments/book_appointment_screen.dart';
import '../appointments/appointment_receipt_screen.dart';
import '../appointments/video_consultation_screen.dart';
import '../medical_history_screen.dart';
import '../prescriptions_screen.dart';
import 'appointments_tab.dart';
import '../../widgets/patient_action_sheets.dart';
import '../rppg_screen.dart';
import '../request_asha_visit_screen.dart';
import '../../widgets/dynamic_translated_text.dart';
import '../../services/localization/app_strings.dart';
import '../../services/localization/healthcare_catalog.dart';
import '../../features/chatbot/chatbot_ui.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  Future<void> _joinTelehealth(BuildContext context, Appointment appointment) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF7C3AED)),
                SizedBox(height: 16),
                Text('Verifying consultation room access...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final res = await PatientDatabaseService().requestTelehealthAccess(appointment.id);
      if (res['success'] != true && res['statusCode'] != null) {
        throw Exception(res['error'] ?? 'Consultation join window is not open.');
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoConsultationScreen(appointment: appointment),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final msg = e.toString().replaceAll('Exception: ', '');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.lock_clock_rounded, color: Color(0xFF7C3AED), size: 40),
            title: const Text('Consultation Room Locked', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              msg.contains('join window')
                  ? 'The secure video consultation room opens 15 minutes before your scheduled appointment time (${appointment.timeSlot}). Please return closer to your slot.'
                  : msg,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildRequestAshaBanner(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RequestAshaVisitScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNITY HEALTHCARE',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFCCFBF1),
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Request ASHA Worker Visit',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Vitals check, BP & pulse, home medical assessment',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFFE6FFFA),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Request',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0F766E)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAshaRequestTrackerCard(BuildContext context, Appointment ashaReq) {
    final notes = ashaReq.notes ?? {};
    final urgency = notes['urgency']?.toString().toLowerCase() ?? 'routine';
    final resolution = notes['resolution']?.toString();
    final status = ashaReq.status.toLowerCase();

    int stage = 1;
    if (status == 'queued') {
      stage = 1;
    } else if (status == 'confirmed' || status == 'in progress' || status == 'in_progress') {
      stage = 2;
    } else if (status == 'completed') {
      stage = 4;
    }

    Color urgencyColor = const Color(0xFF16A34A);
    Color urgencyBg = const Color(0xFFDCFCE7);
    if (urgency == 'priority') {
      urgencyColor = const Color(0xFFD97706);
      urgencyBg = const Color(0xFFFEF3C7);
    } else if (urgency == 'emergency') {
      urgencyColor = const Color(0xFFDC2626);
      urgencyBg = const Color(0xFFFEE2E2);
    }

    final isReferred = resolution == 'referred_to_doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReferred
              ? const Color(0xFFDDD6FE)
              : (stage >= 2 ? const Color(0xFF99F6E4) : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isReferred ? const Color(0xFF7C3AED) : const Color(0xFF0D9488)).withValues(alpha: 0.07),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isReferred ? const Color(0xFFEDE9FE) : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReferred ? Icons.medical_services_rounded : Icons.volunteer_activism_rounded,
                      size: 16,
                      color: isReferred ? const Color(0xFF7C3AED) : const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ASHA HOME VISIT TRACKER',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isReferred ? const Color(0xFF6D28D9) : const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencyBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      urgency.toUpperCase(),
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: urgencyColor),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ashaReq.tokenNumber,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildStepNode(1, 'Sent', stage >= 1, isCurrent: stage == 1),
              _buildStepLine(stage >= 2),
              _buildStepNode(2, 'Accepted', stage >= 2, isCurrent: stage == 2),
              _buildStepLine(stage >= 3),
              _buildStepNode(3, 'Vitals Check', stage >= 3, isCurrent: stage == 3),
              _buildStepLine(stage >= 4),
              _buildStepNode(
                4,
                isReferred ? 'Referred' : 'Resolved',
                stage >= 4,
                isCurrent: stage == 4,
                activeColor: isReferred ? const Color(0xFF7C3AED) : const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason: ',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    Expanded(
                      child: Text(
                        ashaReq.reason,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                if (isReferred) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF7C3AED)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Worker completed assessment and scheduled Doctor Referral. Check Appointments tab.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (stage == 4) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Case Managed in Field by ASHA Worker. Home care advice recorded.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (stage == 2) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'ASHA worker accepted your request and is preparing for the visit.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w500),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Awaiting worker pickup. Local healthcare post alerted.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int step, String label, bool isReached, {bool isCurrent = false, Color? activeColor}) {
    final color = activeColor ?? const Color(0xFF0D9488);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isReached ? color : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
              border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
              boxShadow: isCurrent
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
            child: Center(
              child: isReached
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : Text('$step', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isReached ? FontWeight.bold : FontWeight.w500,
              color: isReached ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isReached) {
    return Container(
      width: 16,
      height: 2,
      margin: const EdgeInsets.only(bottom: 14),
      color: isReached ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<HealthProfileProvider>(context);
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final currentLang = langProvider.currentLanguage;
    final patientName = profileProvider.profile?.name ?? 'Ashwini Patient';
    final nextAppt = appointmentProvider.nextUpcomingAppointment;

    return RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: () async {
        await appointmentProvider.refreshAppointmentsFromBackend();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18.0, 16.0, 18.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 1. WELCOME BACK & PATIENT NAME
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langProvider.tr('welcome_back'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: Color(0xFF8B5CF6), // Soft lavender purple
                      ),
                    ),
                    const SizedBox(height: 3),
                    DynamicTranslatedText(
                      text: patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 5),
                    Text(
                      profileProvider.profile?.patientId ?? 'ASH-PT-8832',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. FULL-WIDTH RECTANGULAR LANGUAGE BUTTON (EN / HI)
          InkWell(
            onTap: () => PatientActionSheets.showLanguageSelector(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEDE9FE), Color(0xFFF5F3FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langProvider.tr('app_language'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6D28D9),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${currentLang.nativeName} (${currentLang.name}) • ${langProvider.tr('change_language')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentLang.badge,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // TOP 11 VOICE LANGUAGES HORIZONTAL QUICK-SELECT BAR
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppLanguages.voiceSupported11Languages.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final vLang = AppLanguages.voiceSupported11Languages[i];
                final isSelected = vLang.code == langProvider.currentLanguageCode;
                return InkWell(
                  onTap: () => langProvider.setLanguage(vLang.code),
                  borderRadius: BorderRadius.circular(17),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          vLang.nativeName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            vLang.badge,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 3. FULL-WIDTH NEWS FLASH BANNER
          const NewsFlashBannerWidget(),
          const SizedBox(height: 14),

          // 4. LIVE UPCOMING CONSULTATION CARD (Or Empty State)
          _buildUpcomingConsultationCard(context, nextAppt),
          const SizedBox(height: 14),

          // LIVE ASHA REQUEST STATUS TRACKER CARD
          if (appointmentProvider.latestAshaRequest != null) ...[
            _buildAshaRequestTrackerCard(context, appointmentProvider.latestAshaRequest!),
            const SizedBox(height: 14),
          ],

          // 5. MEDICINE REMINDER CARD
          const MedicineReminderCard(),
          const SizedBox(height: 18),

          // 5b. CONTACT ASHA WORKER BANNER
          _buildRequestAshaBanner(context),
          const SizedBox(height: 18),

          // 6. QUICK ACTIONS HEADER
          const Row(
            children: [
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 7. 3x2 ACTION CARDS
          Column(
            children: [
              // Row 1: Book Consultation + My Appointments
              Row(
                children: [
                  Expanded(
                    child: _buildMainServiceCard(
                      context,
                      cardKey: const ValueKey('card_book_appointment'),
                      category: langProvider.tr('consultation_sub'),
                      title: langProvider.tr('book_appointment'),
                      icon: Icons.calendar_month_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BookAppointmentScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMainServiceCard(
                      context,
                      cardKey: const ValueKey('card_my_appointments'),
                      category: langProvider.tr('schedule_sub'),
                      title: langProvider.tr('my_appointments'),
                      icon: Icons.event_note_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AppointmentsTab(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 2: Medical History + Prescriptions (LIVE DATA)
              Row(
                children: [
                  Expanded(
                    child: _buildMainServiceCard(
                      context,
                      category: 'RECORDS',
                      title: 'Medical\nHistory',
                      icon: Icons.history_edu_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicalHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMainServiceCard(
                      context,
                      category: 'PHARMACY',
                      title: 'My\nPrescriptions',
                      icon: Icons.receipt_long_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrescriptionsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 3: AI Assistant + Emergency
              Row(
                children: [
                  Expanded(
                    child: _buildMainServiceCard(
                      context,
                      cardKey: const ValueKey('card_ai_assistant'),
                      category: langProvider.tr('instant_ai_sub'),
                      title: langProvider.tr('ai_assistant'),
                      icon: Icons.auto_awesome_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChatbotPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildEmergencyCard(
                      context,
                      cardKey: const ValueKey('card_emergency'),
                      category: langProvider.tr('immediate_sub'),
                      title: langProvider.tr('emergency'),
                      onTap: () => PatientActionSheets.showEmergency(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. PATIENT VITALS BANNER (Deep Royal Purple)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Vitals',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const ListTile(
                          leading: Icon(Icons.favorite, color: Colors.red),
                          title: Text('Blood Pressure'),
                          trailing: Text('120/80 mmHg (Normal)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        const ListTile(
                          leading: Icon(Icons.speed, color: Colors.blue),
                          title: Text('Pulse / Heart Rate'),
                          trailing: Text('72 bpm (Optimal)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        const ListTile(
                          leading: Icon(Icons.water_drop, color: Colors.purple),
                          title: Text('Blood Oxygen (SpO2)'),
                          trailing: Text('98% (Normal)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RppgScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                            foregroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.monitor_heart_rounded),
                          label: const Text('Scan Live Heart Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      offset: const Offset(0, 6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        langProvider.tr('patient_vitals'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4b. LIVE HEART-RATE MONITOR (rPPG Camera Detection Card)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RppgScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDE9FE), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    offset: const Offset(0, 6),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          langProvider.tr('live_vitals'),
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          langProvider.tr('measure_heart_rate'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          langProvider.tr('pulse_scan_sub'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF7C3AED),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

  /// Live Upcoming Consultation Card with instant Telehealth join or Empty State
  Widget _buildUpcomingConsultationCard(BuildContext context, Appointment? nextAppt) {
    if (nextAppt == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF7C3AED), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Upcoming Consultations',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Book video consultations or hospital visits',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Book', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final isTelehealth = nextAppt.isOnline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTelehealth ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isTelehealth ? 'NEXT TELECONSULTATION' : 'NEXT CLINIC CONSULTATION',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  nextAppt.tokenNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nextAppt.doctorName,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            '${nextAppt.doctorSpecialty} • ${nextAppt.hospitalName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFFDDD6FE)),
                const SizedBox(width: 6),
                Text(
                  '${nextAppt.appointmentDate} at ${nextAppt.timeSlot}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (isTelehealth) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinTelehealth(context, nextAppt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B21B6),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentReceiptScreen(appointment: nextAppt),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// White Service Card with watermark & purple accents
  Widget _buildMainServiceCard(
    BuildContext context, {
    Key? cardKey,
    required String category,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: cardKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
              offset: const Offset(0, 8),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative background circle watermark
            Positioned(
              right: -12,
              bottom: -12,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF5F3FF).withValues(alpha: 0.6),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF7C3AED),
                    size: 22,
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    category,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 42,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Emergency Card with soft coral gradient
  Widget _buildEmergencyCard(
    BuildContext context, {
    Key? cardKey,
    required String category,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: cardKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.08),
              offset: const Offset(0, 8),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFECDD3).withValues(alpha: 0.5),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    category,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 42,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


}

/// Prescribed medicine dose structure representing orders from doctor app prescriptions.
class PrescribedDoseItem {
  final String medicineName;
  final String dosage;
  final String timing;
  final String timerBadge;
  final String doctorName;
  final String doctorDept;
  final String instructions;
  final String mealTiming;
  final IconData icon;
  final Color primaryColor;

  const PrescribedDoseItem({
    required this.medicineName,
    required this.dosage,
    required this.timing,
    required this.timerBadge,
    required this.doctorName,
    required this.doctorDept,
    required this.instructions,
    required this.mealTiming,
    required this.icon,
    required this.primaryColor,
  });
}

/// Improvised medicine reminder card with automatic queue advance to next medicine timer,
/// "Mark as taken" action button, and comprehensive prescription schedule modal.
class MedicineReminderCard extends StatefulWidget {
  const MedicineReminderCard({super.key});

  @override
  State<MedicineReminderCard> createState() => _MedicineReminderCardState();
}

class _MedicineReminderCardState extends State<MedicineReminderCard> {
  // Queue of doctor-prescribed medicine doses for today (ordered by scheduled time)
  final List<PrescribedDoseItem> _prescribedDoses = const [
    PrescribedDoseItem(
      medicineName: 'Paracetamol 500mg',
      dosage: '1 Tablet (500mg)',
      timing: '2:00 PM',
      timerBadge: 'Due in 15 mins',
      doctorName: 'Dr. Ananya Sharma',
      doctorDept: 'Cardiology (AIIMS)',
      instructions: 'Take with warm water after lunch',
      mealTiming: 'After Lunch',
      icon: Icons.medication_rounded,
      primaryColor: Color(0xFF7C3AED),
    ),
    PrescribedDoseItem(
      medicineName: 'Vitamin D3 & Calcium',
      dosage: '1 Capsule (60,000 IU)',
      timing: '5:30 PM',
      timerBadge: 'In 3h 15m (5:30 PM)',
      doctorName: 'Dr. Rajesh Verma',
      doctorDept: 'General Medicine',
      instructions: 'Take with milk or juice after light evening snack',
      mealTiming: 'Evening Snack',
      icon: Icons.bubble_chart_rounded,
      primaryColor: Color(0xFF0D9488),
    ),
    PrescribedDoseItem(
      medicineName: 'Telmisartan 40mg',
      dosage: '1 Tablet (40mg)',
      timing: '8:30 PM',
      timerBadge: 'In 6h 15m (8:30 PM)',
      doctorName: 'Dr. Ananya Sharma',
      doctorDept: 'Cardiology (AIIMS)',
      instructions: 'Maintain low-sodium dinner. Monitor blood pressure before sleep.',
      mealTiming: 'After Dinner',
      icon: Icons.favorite_rounded,
      primaryColor: Color(0xFFE11D48),
    ),
    PrescribedDoseItem(
      medicineName: 'Pantoprazole 40mg',
      dosage: '1 Tablet (40mg)',
      timing: '10:00 PM',
      timerBadge: 'In 7h 45m (10:00 PM)',
      doctorName: 'Dr. Rajesh Verma',
      doctorDept: 'General Medicine',
      instructions: 'Take 30 mins before sleep with plain water',
      mealTiming: 'Before Bedtime',
      icon: Icons.nightlight_round,
      primaryColor: Color(0xFF2563EB),
    ),
  ];

  int _currentDoseIndex = 0;
  bool _allCompleted = false;
  bool _isTransitioning = false;

  void _markCurrentDoseAsTaken() {
    if (_allCompleted || _isTransitioning) return;

    HapticFeedback.mediumImpact();
    final currentDose = _prescribedDoses[_currentDoseIndex];
    final nextIndex = _currentDoseIndex + 1;

    setState(() {
      _isTransitioning = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nextIndex < _prescribedDoses.length
                    ? '${currentDose.medicineName} marked as taken! Next timer: ${_prescribedDoses[nextIndex].medicineName} (${_prescribedDoses[nextIndex].timing})'
                    : '${currentDose.medicineName} marked as taken! All prescribed doses for today completed.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 3),
      ),
    );

    // Automatically advance to the next medicine timer in queue
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!mounted) return;
      setState(() {
        _isTransitioning = false;
        if (nextIndex < _prescribedDoses.length) {
          _currentDoseIndex = nextIndex;
        } else {
          _allCompleted = true;
        }
      });
    });
  }

  void _resetDoses() {
    setState(() {
      _currentDoseIndex = 0;
      _allCompleted = false;
      _isTransitioning = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription schedule reset for demo testing.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF475569),
      ),
    );
  }

  String _translateMealTiming(String meal, LanguageProvider langProvider) {
    switch (meal) {
      case 'After Lunch':
        return langProvider.tr('after_lunch');
      case 'Evening Snack':
        return langProvider.tr('evening_snack');
      case 'After Dinner':
        return langProvider.tr('after_dinner');
      case 'Before Bedtime':
        return langProvider.tr('before_bedtime');
      case 'Before Breakfast':
        return langProvider.tr('before_breakfast');
      default:
        return meal;
    }
  }

  void _showDoseDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final langProvider = Provider.of<LanguageProvider>(context);
          final currentDose = _allCompleted
              ? _prescribedDoses.last
              : _prescribedDoses[_currentDoseIndex];

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [currentDose.primaryColor, currentDose.primaryColor.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: currentDose.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(currentDose.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DOCTOR PRESCRIPTION QUEUE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_allCompleted ? _prescribedDoses.length : _currentDoseIndex}/${_prescribedDoses.length} Completed',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _allCompleted
                              ? Text(
                                  langProvider.tr('all_meds_taken'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                )
                              : DynamicTranslatedText(
                                  text: currentDose.medicineName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                          const SizedBox(height: 2),
                          Text(
                            _allCompleted
                                ? langProvider.tr('next_dose_tomorrow')
                                : '${HealthcareCatalog.lookup(currentDose.dosage, langProvider.currentLanguageCode) ?? currentDose.dosage} • ${_translateMealTiming(currentDose.mealTiming, langProvider)} (${currentDose.timing})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Today's Doctor Prescribed Schedule List
                Text(
                  langProvider.tr('doctor_queue'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _prescribedDoses.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final dose = _prescribedDoses[i];
                      final isTaken = _allCompleted || i < _currentDoseIndex;
                      final isCurrent = !_allCompleted && i == _currentDoseIndex;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFFFAF5FF)
                              : (isTaken ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFFDDD6FE)
                                : (isTaken ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                            width: isCurrent ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? const Color(0xFFDCFCE7)
                                    : (isCurrent ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isTaken
                                    ? Icons.check_circle_rounded
                                    : (isCurrent ? Icons.alarm_rounded : Icons.schedule_rounded),
                                size: 16,
                                color: isTaken
                                    ? const Color(0xFF16A34A)
                                    : (isCurrent ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      DynamicTranslatedText(
                                        text: dose.medicineName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isTaken ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                                          decoration: isTaken ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${dose.timing})',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${HealthcareCatalog.lookup(dose.dosage, langProvider.currentLanguageCode) ?? dose.dosage} • ${HealthcareCatalog.lookup(dose.doctorName, langProvider.currentLanguageCode) ?? dose.doctorName}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isTaken
                                    ? const Color(0xFFDCFCE7)
                                    : (isCurrent ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isTaken
                                    ? langProvider.tr('dose_taken_badge')
                                    : (isCurrent ? langProvider.tr('due_next_badge') : langProvider.tr('upcoming_badge')),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isTaken
                                      ? const Color(0xFF16A34A)
                                      : (isCurrent ? const Color(0xFF6D28D9) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Modal Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(langProvider.tr('reminder_snoozed')),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF475569),
                            ),
                          );
                        },
                        icon: const Icon(Icons.snooze_rounded, size: 16),
                        label: Text(langProvider.tr('snooze_15m')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          foregroundColor: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (_allCompleted) {
                            _resetDoses();
                          } else {
                            _markCurrentDoseAsTaken();
                          }
                        },
                        icon: Icon(
                          _allCompleted ? Icons.restart_alt_rounded : Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: Text(_allCompleted ? langProvider.tr('reset_schedule') : langProvider.tr('mark_as_taken')),
                        style: FilledButton.styleFrom(
                          backgroundColor: _allCompleted ? const Color(0xFF475569) : const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    if (_allCompleted) {
      // Completed State for today
      return InkWell(
        onTap: _showDoseDetails,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFF7FEE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.verified_rounded, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langProvider.tr('dose_taken_badge'),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      langProvider.tr('all_meds_taken'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      langProvider.tr('next_dose_tomorrow'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _resetDoses,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF15803D)),
                        const SizedBox(width: 4),
                        Text(
                          langProvider.tr('reset_btn'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentDose = _prescribedDoses[_currentDoseIndex];

    return InkWell(
      onTap: _showDoseDetails,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFAF5FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Glowing Icon Badge with Current Dose Theme
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    currentDose.primaryColor.withValues(alpha: 0.9),
                    currentDose.primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: currentDose.primaryColor.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                currentDose.icon,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 9),

            // Middle: Reminder Tags, Title, Subtitle (With zero overflow risk)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C3AED),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3.5),
                              Flexible(
                                child: Text(
                                  langProvider.tr('reminder'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFDE68A),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.alarm_rounded,
                                size: 10,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  HealthcareCatalog.lookup(currentDose.timerBadge, langProvider.currentLanguageCode) ??
                                      (currentDose.timerBadge == 'Due in 15 mins'
                                          ? langProvider.tr('due_in_15')
                                          : currentDose.timerBadge),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  DynamicTranslatedText(
                    text: currentDose.medicineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    '${currentDose.timing} • ${_translateMealTiming(currentDose.mealTiming, langProvider)} • ${HealthcareCatalog.lookup(currentDose.doctorName, langProvider.currentLanguageCode) ?? currentDose.doctorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // "Mark as taken" Action Button (Compact & Overflow-Proof)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('btn_mark_taken'),
                onTap: _markCurrentDoseAsTaken,
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(maxWidth: 110),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7.5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTransitioning
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isTransitioning ? const Color(0xFF10B981) : const Color(0xFF7C3AED)).withValues(alpha: 0.32),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTransitioning ? Icons.done_all_rounded : Icons.check_circle_outline_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3.5),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _isTransitioning ? 'Done!' : langProvider.tr('mark_as_taken'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
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


