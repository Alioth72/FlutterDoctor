import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../services/patient_database_service.dart';
import '../../widgets/news_flash_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/health_profile_provider.dart';
import '../appointments/book_appointment_screen.dart';
import '../appointments/appointment_receipt_screen.dart';
import '../appointments/video_consultation_screen.dart';
import '../medical_history_screen.dart';
import '../prescriptions_screen.dart';
import 'appointments_tab.dart';
import '../../widgets/patient_action_sheets.dart';
import '../rppg_screen.dart';

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
      await PatientDatabaseService().requestTelehealthAccess(appointment.id);
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

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<HealthProfileProvider>(context);
    final appointmentProvider = Provider.of<AppointmentProvider>(context);
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WELCOME BACK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    patientName,
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APP LANGUAGE • भाषा',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6D28D9),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'English / हिन्दी (Change Language)',
                          style: TextStyle(
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EN / HI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
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
          const SizedBox(height: 16),

          // 3. FULL-WIDTH NEWS FLASH BANNER
          const NewsFlashBannerWidget(),
          const SizedBox(height: 14),

          // 4. LIVE UPCOMING CONSULTATION CARD (Or Empty State)
          _buildUpcomingConsultationCard(context, nextAppt),
          const SizedBox(height: 14),

          // 5. MEDICINE REMINDER CARD
          const MedicineReminderCard(),
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
                      category: 'CONSULTATION',
                      title: 'Book\nConsultation',
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
                      category: 'SCHEDULE',
                      title: 'My\nAppointments',
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
                      category: 'SYMPTOM CHECKER',
                      title: 'AI\nAssistant',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => PatientActionSheets.showAiAssistant(context),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildEmergencyCard(
                      context,
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
                    const Expanded(
                      child: Text(
                        'Patient Vitals',
                        style: TextStyle(
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE VITALS',
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Measure Live Heart Rate',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Instant pulse scan via on-device AI camera',
                          style: TextStyle(
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
    required String category,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(16),
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
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: Color(0xFF0F172A),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 155,
        padding: const EdgeInsets.all(16),
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
                const Text(
                  '24/7 HOTLINE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'EMERGENCY',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: Color(0xFF991B1B),
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

  void _showDoseDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
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
                          Text(
                            _allCompleted
                                ? 'All Prescribed Doses Completed!'
                                : currentDose.medicineName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _allCompleted
                                ? 'Next dose tomorrow at 8:00 AM'
                                : '${currentDose.dosage} • ${currentDose.mealTiming} (${currentDose.timing})',
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
                const Text(
                  'TODAY\'S PRESCRIBED DOSES (DOCTOR QUEUE)',
                  style: TextStyle(
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                      Text(
                                        dose.medicineName,
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
                                    '${dose.dosage} • ${dose.doctorName}',
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
                                    ? 'TAKEN ✓'
                                    : (isCurrent ? 'DUE NEXT' : 'UPCOMING'),
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
                            const SnackBar(
                              content: Text('Reminder snoozed for 15 minutes.'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Color(0xFF475569),
                            ),
                          );
                        },
                        icon: const Icon(Icons.snooze_rounded, size: 16),
                        label: const Text('Snooze 15m'),
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
                        label: Text(_allCompleted ? 'Reset Schedule' : 'Mark as taken'),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALL DOSES COMPLETED TODAY ✓',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'All Today\'s Medicines Taken!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Next prescription dose starts tomorrow at 8:00 AM',
                      style: TextStyle(
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          'Reset',
                          style: TextStyle(
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
                      Container(
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
                            const Text(
                              'REMINDER',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ],
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
                                  currentDose.timerBadge,
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
                  Text(
                    currentDose.medicineName,
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
                    '${currentDose.timing} • ${currentDose.mealTiming} • ${currentDose.doctorName.split(' ')[0]} ${currentDose.doctorName.split(' ')[1]}',
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
                onTap: _markCurrentDoseAsTaken,
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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
                      Text(
                        _isTransitioning ? 'Done!' : 'Mark as taken',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                          color: Colors.white,
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


