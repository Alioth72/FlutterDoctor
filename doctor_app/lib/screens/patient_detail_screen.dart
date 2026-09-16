import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../models/appointment_model.dart';
import '../services/api_client.dart';
import '../widgets/rppg_camera_modal.dart';

class PatientDetailScreen extends StatefulWidget {
  final HospitalAdminPatient patient;
  final UserProfile? userProfile;
  final VoidCallback? onAppointmentCreated;
  final AppointmentItem? initialAshaRequest;
  final bool openAssessmentImmediately;

  const PatientDetailScreen({
    super.key,
    required this.patient,
    this.userProfile,
    this.onAppointmentCreated,
    this.initialAshaRequest,
    this.openAssessmentImmediately = false,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _isLoadingAppointments = false;
  bool _isLoadingRecords = false;
  List<AppointmentItem> _patientAppointments = [];
  List<Map<String, dynamic>> _patientMedicalRecords = [];
  List<Map<String, dynamic>> _liveDoctors = [];
  List<Map<String, dynamic>> _liveFacilities = [];

  @override
  void initState() {
    super.initState();
    _loadPatientAppointments();
    _loadPatientMedicalRecords();
    _loadDoctorsAndFacilities();

    if (widget.openAssessmentImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAshaAssessmentModal(widget.initialAshaRequest);
      });
    }
  }

  Future<void> _loadPatientAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final list = await ApiClient.getAppointments(patientId: widget.patient.id);
      if (!mounted) return;
      setState(() {
        _patientAppointments = list ?? [];
        _isLoadingAppointments = false;
      });
    } catch (e) {
      debugPrint('Error loading patient appointments: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _loadPatientMedicalRecords() async {
    setState(() => _isLoadingRecords = true);
    try {
      final records = await ApiClient.getPatientMedicalRecords(widget.patient.id);
      if (!mounted) return;
      setState(() {
        _patientMedicalRecords = records;
        _isLoadingRecords = false;
      });
    } catch (e) {
      debugPrint('Error loading patient medical records: $e');
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  Future<void> _loadDoctorsAndFacilities() async {
    try {
      final docs = await ApiClient.getDoctors();
      final facs = await ApiClient.getFacilities();
      if (!mounted) return;
      setState(() {
        _liveDoctors = docs;
        _liveFacilities = facs;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          p.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh History',
            onPressed: _loadPatientAppointments,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPatientAppointments,
        color: const Color(0xFF0F766E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Patient Profile Card
              _buildPatientProfileCard(p),

              const SizedBox(height: 16),

              // 1b. ASHA Field Health Assessment Banner
              _buildAshaAssessmentBanner(),

              const SizedBox(height: 16),

              // 2. Quick Action Bar: Create Appointment
              _buildCreateAppointmentBanner(),

              const SizedBox(height: 20),

              // 3. Consultation & Appointment History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, color: Color(0xFF0F766E), size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Consultation History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_patientAppointments.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _openCreateAppointmentModal(),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF0F766E)),
                    label: const Text(
                      'New Appointment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildAppointmentsList(),

              const SizedBox(height: 24),

              // 4. Clinical Assessments & Medical Records Section
              _buildMedicalRecordsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateAppointmentModal(),
        backgroundColor: const Color(0xFF0F766E),
        icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
        label: const Text(
          'Create Appointment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ==========================================================
  // PATIENT PROFILE CARD
  // ==========================================================
  Widget _buildPatientProfileCard(HospitalAdminPatient p) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: p.gender.toLowerCase() == 'female'
                      ? const Color(0xFFFCE7F3)
                      : const Color(0xFFE0F2FE),
                  child: Icon(
                    p.gender.toLowerCase() == 'female' ? Icons.female_rounded : Icons.male_rounded,
                    color: p.gender.toLowerCase() == 'female' ? const Color(0xFFDB2777) : const Color(0xFF0284C7),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.isAdmitted ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.isAdmitted ? 'INPATIENT' : 'OPD / FIELD',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${p.age} Yrs • ${p.gender} • Blood: ${p.bloodGroup ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'MRN: ${p.medicalRecordNumber ?? "N/A"}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.phone_rounded, p.phone),
                _buildInfoChip(Icons.local_hospital_rounded, p.hospitalName),
                if (p.assignedDoctor.isNotEmpty)
                  _buildInfoChip(Icons.medical_services_rounded, p.assignedDoctor),
                _buildInfoChip(Icons.medical_information_rounded, p.diagnosis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ==========================================================
  // ASHA ASSESSMENT BANNER
  // ==========================================================
  Widget _buildAshaAssessmentBanner() {
    final hasAshaReq = widget.initialAshaRequest != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
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
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ASHA Clinical Assessment',
                      style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    if (hasAshaReq) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ACTIVE REQUEST', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Measure camera rPPG heart rate, physical vitals, and manage or refer.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openAshaAssessmentModal(widget.initialAshaRequest),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2DD4BF),
              foregroundColor: const Color(0xFF134E4A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Assess', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CREATE APPOINTMENT BANNER
  // ==========================================================
  Widget _buildCreateAppointmentBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF115E59), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Doctor Consultation',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Book appointment with specialist for ${widget.patient.name}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openCreateAppointmentModal(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // APPOINTMENTS LIST (HISTORY PRESERVATION)
  // ==========================================================
  Widget _buildAppointmentsList() {
    if (_isLoadingAppointments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
        ),
      );
    }

    if (_patientAppointments.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 10),
              const Text(
                'No Consultations Found',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create an appointment to book a specialist for this patient.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _openCreateAppointmentModal(),
                icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                label: const Text('Create First Appointment', style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _patientAppointments.map((appt) => _buildAppointmentCard(appt)).toList(),
    );
  }

  Widget _buildAppointmentCard(AppointmentItem appt) {
    Color statusColor;
    Color statusBg;
    switch (appt.status.toLowerCase()) {
      case 'confirmed':
        statusColor = const Color(0xFF0D9488);
        statusBg = const Color(0xFFCCFBF1);
        break;
      case 'in_progress':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'completed':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'cancelled':
      case 'no_show':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = const Color(0xFF6366F1);
        statusBg = const Color(0xFFEEF2FF);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showConsultationDetailsSheet(appt),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Appt No & Status Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          appt.appointmentNo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              appt.mode == AppointmentMode.teleconsultation ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                              size: 11,
                              color: const Color(0xFF0F766E),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              appt.mode == AppointmentMode.teleconsultation ? 'Telehealth' : 'In-Person',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appt.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Doctor & Timing
              Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFCCFBF1),
                    child: Icon(Icons.person, color: Color(0xFF0F766E), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appt.doctorName ?? 'Assigned Doctor',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          appt.timing,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 8),

              // Reason
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Text(
                  'Reason: ${appt.diagnosis}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                ),
              ),

              if (appt.medicines.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.medication_rounded, size: 13, color: Color(0xFF0F766E)),
                    const SizedBox(width: 4),
                    Text(
                      '${appt.medicines.length} Medication(s) Prescribed',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // CONSULTATION DETAILS MODAL SHEET (WORKER NATIVE - NO COLOR SHIFT)
  // ==========================================================
  void _showConsultationDetailsSheet(AppointmentItem appt) {
    Color statusColor;
    Color statusBg;
    switch (appt.status.toLowerCase()) {
      case 'confirmed':
        statusColor = const Color(0xFF0D9488);
        statusBg = const Color(0xFFCCFBF1);
        break;
      case 'in_progress':
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case 'completed':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        break;
      case 'cancelled':
      case 'no_show':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        break;
      default:
        statusColor = const Color(0xFF0F766E);
        statusBg = const Color(0xFFE6FFFA);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Color(0xFF0F766E),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              appt.appointmentNo,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                appt.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Consultation Record Details',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // 3. Scrollable Details Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor & Timing Summary Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFCCFBF1),
                                  child: Icon(Icons.medical_services_rounded, color: Color(0xFF0F766E), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        appt.doctorName ?? 'Assigned Doctor',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        appt.medicines.isNotEmpty && appt.medicines.first.closestClinic.isNotEmpty
                                            ? appt.medicines.first.closestClinic
                                            : 'Ashwini Central Hospital',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF0F766E)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            appt.timing,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          appt.mode == AppointmentMode.teleconsultation ? Icons.videocam_rounded : Icons.local_hospital_rounded,
                                          size: 14,
                                          color: const Color(0xFF0F766E),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            appt.mode == AppointmentMode.teleconsultation ? 'Telehealth' : 'In-Person Clinic',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reason / Chief Complaint
                      const Text(
                        'CHIEF COMPLAINT / REASON',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          appt.diagnosis.isNotEmpty ? appt.diagnosis : 'General medical review and assessment',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clinical Vitals Section (if available)
                      if (appt.clinicalData != null && appt.clinicalData!.isNotEmpty) ...[
                        const Text(
                          'CLINICAL VITALS RECORDED',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (appt.clinicalData!['bp'] != null)
                                _buildVitalBadge('BP', '${appt.clinicalData!['bp']}'),
                              if (appt.clinicalData!['spo2'] != null)
                                _buildVitalBadge('SpO2', '${appt.clinicalData!['spo2']}'),
                              if (appt.clinicalData!['temp'] != null)
                                _buildVitalBadge('Temp', '${appt.clinicalData!['temp']}'),
                              if (appt.clinicalData!['pulse'] != null)
                                _buildVitalBadge('Pulse', '${appt.clinicalData!['pulse']}'),
                              if (appt.weightKg > 0)
                                _buildVitalBadge('Weight', '${appt.weightKg.toInt()} kg'),
                              if (appt.heightCm > 0)
                                _buildVitalBadge('Height', '${appt.heightCm.toInt()} cm'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Prescribed Medications
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PRESCRIBED MEDICATIONS (${appt.medicines.length})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          if (appt.medicines.isNotEmpty)
                            const Text(
                              'Verified by Doctor',
                              style: TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (appt.medicines.isNotEmpty)
                        ...appt.medicines.map((med) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.medication_rounded, size: 16, color: Color(0xFF0F766E)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          med.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                med.dosage,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                med.duration,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (med.closestClinic.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Pharmacy: ${med.closestClinic}',
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ))
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text(
                              'No medications issued for this consultation yet.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Administrative & Billing Details
                      const Text(
                        'BILLING & STATUS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payment_rounded, size: 16, color: Color(0xFF0F766E)),
                                const SizedBox(width: 8),
                                Text(
                                  appt.paymentStatus,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: appt.isAdmitted ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                appt.isAdmitted ? 'INPATIENT' : 'OUTPATIENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: appt.isAdmitted ? const Color(0xFFDC2626) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Close Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Close Details',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVitalBadge(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          Text(val, style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================================
  // CREATE APPOINTMENT MODAL SHEET
  // ==========================================================
  void _openCreateAppointmentModal() {
    // 1. Doctors options
    final doctorsList = _liveDoctors.isNotEmpty
        ? _liveDoctors
        : HospitalAdminRepository.getAllDoctors().map((d) => {
              'user_id': d.id,
              'full_name': d.name,
              'specialties': [d.department],
            }).toList();

    String? selectedDoctorId = widget.patient.assignedDoctorUserId;
    if (selectedDoctorId == null || !doctorsList.any((d) => d['user_id']?.toString() == selectedDoctorId)) {
      selectedDoctorId = doctorsList.isNotEmpty ? doctorsList.first['user_id']?.toString() : null;
    }

    // 2. Facilities options
    final facilitiesList = _liveFacilities.isNotEmpty
        ? _liveFacilities
        : [
            {'facility_id': 'f48c08ef-a5e2-41b1-bce7-742db5e20601', 'name': 'Ashwini Central Hospital'},
            {'facility_id': 'f48c08ef-a5e2-41b1-bce7-742db5e20602', 'name': 'AIIMS New Delhi'},
          ];

    String? selectedFacilityId = facilitiesList.first['facility_id']?.toString();

    // 3. Appointment parameters
    String selectedType = 'clinic'; // clinic, telehealth, home_visit, pharmacy
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final reasonController = TextEditingController(
      text: widget.patient.diagnosis.isNotEmpty && widget.patient.diagnosis != 'Outpatient Care'
          ? 'Clinical consultation for ${widget.patient.diagnosis}'
          : 'Routine primary healthcare checkup and clinical assessment',
    );
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_task_rounded, color: Color(0xFF0F766E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Create New Appointment',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Shared Azure Cloud • PostgreSQL Verified',
                              style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // PRE-SELECTED PATIENT CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: Color(0xFF0F766E), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patient.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'MRN: ${widget.patient.medicalRecordNumber ?? "N/A"} • Phone: ${widget.patient.phone}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRE-SELECTED',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. SELECT DOCTOR
                  const Text(
                    '1. Select Doctor (Specialist)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedDoctorId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF0F766E), size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    isExpanded: true,
                    items: doctorsList.map((d) {
                      final docId = d['user_id']?.toString() ?? '';
                      final docName = d['full_name']?.toString() ?? 'Doctor';
                      final specList = d['specialties'] is List ? (d['specialties'] as List).join(', ') : '';
                      return DropdownMenuItem<String>(
                        value: docId,
                        child: Text(
                          specList.isNotEmpty ? '$docName ($specList)' : docName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedDoctorId = val),
                  ),
                  const SizedBox(height: 14),

                  // 2. SELECT FACILITY / CLINIC
                  const Text(
                    '2. Select Facility / Clinic',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedFacilityId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF0F766E), size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    isExpanded: true,
                    items: facilitiesList.map((f) {
                      final facId = f['facility_id']?.toString() ?? '';
                      final facName = f['name']?.toString() ?? 'Hospital';
                      return DropdownMenuItem<String>(
                        value: facId,
                        child: Text(facName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() => selectedFacilityId = val),
                  ),
                  const SizedBox(height: 14),

                  // 3. APPOINTMENT TYPE
                  const Text(
                    '3. Consultation Mode',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildTypeChoiceChip(
                        label: 'In-Person Clinic',
                        icon: Icons.local_hospital_rounded,
                        typeKey: 'clinic',
                        selectedType: selectedType,
                        onTap: () => setModalState(() => selectedType = 'clinic'),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChoiceChip(
                        label: 'Telehealth',
                        icon: Icons.videocam_rounded,
                        typeKey: 'telehealth',
                        selectedType: selectedType,
                        onTap: () => setModalState(() => selectedType = 'telehealth'),
                      ),
                      const SizedBox(width: 8),
                      _buildTypeChoiceChip(
                        label: 'Home Visit',
                        icon: Icons.home_rounded,
                        typeKey: 'home_visit',
                        selectedType: selectedType,
                        onTap: () => setModalState(() => selectedType = 'home_visit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. DATE & TIME SELECTION
                  const Text(
                    '4. Consultation Date & Time',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Date Picker Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 60)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F766E)),
                          label: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Time Picker Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              setModalState(() => selectedTime = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0F766E)),
                          label: Text(
                            selectedTime.format(ctx),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. CLINICAL REASON / SYMPTOMS
                  const Text(
                    '5. Clinical Reason / Symptoms',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Chronic joint pain, persistent dry cough',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 6. FIELD NOTES
                  const Text(
                    '6. Field Notes (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'e.g. Field SpO2: 97%, Blood Pressure: 120/80',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SUBMIT APPOINTMENT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedDoctorId == null || selectedDoctorId!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a doctor.')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final scheduledDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              final notesMap = <String, dynamic>{
                                if (notesController.text.trim().isNotEmpty)
                                  'field_worker_notes': notesController.text.trim(),
                              };

                              final res = await ApiClient.createAppointment(
                                patientId: widget.patient.id,
                                doctorUserId: selectedDoctorId!,
                                facilityId: selectedFacilityId,
                                appointmentType: selectedType,
                                scheduledStart: scheduledDateTime,
                                status: 'confirmed',
                                reason: reasonController.text.trim().isNotEmpty
                                    ? reasonController.text.trim()
                                    : 'Clinical Consultation',
                                notes: notesMap.isNotEmpty ? notesMap : null,
                              );

                              if (!mounted) return;

                              if (res['success'] == true) {
                                Navigator.pop(ctx);
                                _loadPatientAppointments();
                                widget.onAppointmentCreated?.call();

                                final data = res['data'] is Map ? res['data'] as Map : {};
                                final aptNo = (data['notes'] is Map ? data['notes']['appointment_no'] : null) ?? 'Confirmed';

                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                        SizedBox(width: 10),
                                        Text('Appointment Created!'),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Appointment $aptNo has been confirmed in PostgreSQL on Azure.'),
                                        const SizedBox(height: 10),
                                        Text('Patient: ${widget.patient.name}'),
                                        Text('Consultation Mode: ${selectedType.toUpperCase()}'),
                                        Text('Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at ${selectedTime.format(context)}'),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'Visible immediately to Worker, Doctor, and Admin portals.',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['error']?.toString() ?? 'Failed to create appointment.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Confirm & Submit Appointment',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChoiceChip({
    required String label,
    required IconData icon,
    required String typeKey,
    required String selectedType,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedType == typeKey;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F766E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF475569)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // MEDICAL RECORDS & FIELD CARE SECTION
  // ==========================================================
  Widget _buildMedicalRecordsSection() {
    if (_isLoadingRecords) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
        ),
      );
    }

    if (_patientMedicalRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F766E), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Field Care & Clinical Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_patientMedicalRecords.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._patientMedicalRecords.map((rec) => _buildMedicalRecordCard(rec)),
      ],
    );
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> rec) {
    final clinicalData = rec['clinical_data'] is Map ? rec['clinical_data'] as Map : {};
    final assessmentType = clinicalData['assessment_type']?.toString() ?? rec['record_type']?.toString() ?? 'triage';
    final decision = clinicalData['decision']?.toString() ?? 'managed';
    final vitals = clinicalData['vitals'] is Map ? clinicalData['vitals'] as Map : {};
    final createdAt = rec['created_at']?.toString() ?? '';
    final isAsha = assessmentType == 'asha_assessment';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF0F766E)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAsha ? 'ASHA Field Assessment' : 'Clinical Record',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: decision == 'referred_to_doctor' ? const Color(0xFFEDE9FE) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    decision == 'referred_to_doctor' ? 'REFERRED TO DOCTOR' : 'MANAGED IN FIELD',
                    style: TextStyle(
                      color: decision == 'referred_to_doctor' ? const Color(0xFF6D28D9) : const Color(0xFF059669),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Vitals Chips
            if (vitals.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (vitals['heart_rate_bpm'] != null)
                    _buildClinicalRecordBadge(Icons.favorite_rounded, '${vitals['heart_rate_bpm']} BPM', Colors.red.shade600),
                  if (vitals['blood_pressure'] != null)
                    _buildClinicalRecordBadge(Icons.speed_rounded, 'BP: ${vitals['blood_pressure']} mmHg', Colors.indigo.shade600),
                  if (vitals['spo2_percent'] != null)
                    _buildClinicalRecordBadge(Icons.air_rounded, 'SpO2: ${vitals['spo2_percent']}%', Colors.teal.shade700),
                  if (vitals['temperature_c'] != null)
                    _buildClinicalRecordBadge(Icons.thermostat_rounded, '${vitals['temperature_c']}°C', Colors.amber.shade800),
                  if (vitals['blood_glucose_mg_dl'] != null)
                    _buildClinicalRecordBadge(Icons.water_drop_rounded, 'Glu: ${vitals['blood_glucose_mg_dl']} mg/dL', Colors.purple.shade700),
                  if (vitals['weight_kg'] != null)
                    _buildClinicalRecordBadge(Icons.monitor_weight_rounded, '${vitals['weight_kg']} kg', Colors.blueGrey.shade700),
                ],
              ),
              const SizedBox(height: 8),
            ],

            if (clinicalData['symptoms'] != null && clinicalData['symptoms'].toString().isNotEmpty) ...[
              Text(
                'Symptoms: ${clinicalData['symptoms']}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
            ],

            if (clinicalData['field_care_advice'] != null && clinicalData['field_care_advice'].toString().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text(
                  'Advice: ${clinicalData['field_care_advice']}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                ),
              ),
              const SizedBox(height: 4),
            ],

            if (createdAt.isNotEmpty)
              Text(
                'Recorded: ${createdAt.replaceAll("T", " ").split(".").first}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalRecordBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ==========================================================
  // ASHA CLINICAL ASSESSMENT & VITALS MODAL
  // ==========================================================
  void _openAshaAssessmentModal(AppointmentItem? ashaReq) {
    // Vitals Controllers - Completely empty initially per requirements
    final hrController = TextEditingController();
    final bpSysController = TextEditingController();
    final bpDiaController = TextEditingController();
    final spo2Controller = TextEditingController();
    final tempController = TextEditingController();
    final glucoseController = TextEditingController();
    final weightController = TextEditingController();
    final rrController = TextEditingController();

    // Clinical Details
    final symptomsController = TextEditingController(text: ashaReq?.diagnosis ?? '');
    final observationsController = TextEditingController();
    final fieldCareController = TextEditingController();

    // Decision Mode: 'manage' or 'refer'
    String decisionMode = 'manage';

    // Doctor Referral Parameters
    final doctorsList = _liveDoctors.isNotEmpty
        ? _liveDoctors
        : HospitalAdminRepository.getAllDoctors().map((d) => {
              'user_id': d.id,
              'full_name': d.name,
              'specialties': [d.department],
            }).toList();

    String? selectedDoctorId = widget.patient.assignedDoctorUserId;
    if (selectedDoctorId == null || !doctorsList.any((d) => d['user_id']?.toString() == selectedDoctorId)) {
      selectedDoctorId = doctorsList.isNotEmpty ? doctorsList.first['user_id']?.toString() : null;
    }

    DateTime selectedDate = DateTime.now();
    final timeSlots = [
      '09:00 - 09:30 AM',
      '09:30 - 10:00 AM',
      '10:00 - 10:30 AM',
      '10:30 - 11:00 AM',
      '11:00 - 11:30 AM',
      '11:30 - 12:00 PM',
      '02:00 - 02:30 PM',
      '02:30 - 03:00 PM',
      '03:00 - 03:30 PM',
      '03:30 - 04:00 PM',
      '04:00 - 04:30 PM',
    ];
    String selectedSlot = timeSlots[2]; // 10:00 - 10:30 AM
    String selectedConsultationType = 'telehealth'; // telehealth or clinic
    final referralReasonController = TextEditingController(
      text: ashaReq?.diagnosis.isNotEmpty ?? false
          ? ashaReq!.diagnosis
          : 'Referred by ASHA Worker for specialist doctor clinical consultation',
    );

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Modal Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF0F766E), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ASHA Clinical Field Assessment',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Patient: ${widget.patient.name} (${widget.patient.age} yrs, ${widget.patient.gender})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 1. VITALS SECTION
                  // ==========================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Vital Signs (Real Camera rPPG + Manual Device Inputs)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Heart rate uses real phone camera rPPG. All other vitals are entered manually from physical diagnostic devices.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),

                  // Real Camera Heart Rate Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Heart Rate (BPM)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF9F1239)),
                              ),
                              Text(
                                hrController.text.isNotEmpty
                                    ? '${hrController.text} BPM Measured'
                                    : 'Scan with camera or enter manually',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: hrController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9F1239)),
                            decoration: InputDecoration(
                              hintText: 'BPM',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final bpm = await showModalBottomSheet<double>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (c) => const RppgCameraModal(),
                            );
                            if (bpm != null) {
                              setModalState(() {
                                hrController.text = bpm.toStringAsFixed(0);
                              });
                            }
                          },
                          icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          label: const Text('Measure', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE11D48),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Manual Inputs Grid (All start EMPTY, validation on submit)
                  Row(
                    children: [
                      // Blood Pressure Systolic
                      Expanded(
                        child: TextField(
                          controller: bpSysController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'BP Systolic',
                            hintText: 'mmHg',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Blood Pressure Diastolic
                      Expanded(
                        child: TextField(
                          controller: bpDiaController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'BP Diastolic',
                            hintText: 'mmHg',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // SpO2
                      Expanded(
                        child: TextField(
                          controller: spo2Controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'SpO2 (%)',
                            hintText: 'e.g. 98',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Temp
                      Expanded(
                        child: TextField(
                          controller: tempController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Temperature (°C)',
                            hintText: 'e.g. 37.0',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Glucose
                      Expanded(
                        child: TextField(
                          controller: glucoseController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Blood Glucose',
                            hintText: 'mg/dL',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Weight
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            hintText: 'e.g. 68.5',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Respiratory Rate
                  TextField(
                    controller: rrController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Respiratory Rate (breaths/min)',
                      hintText: 'e.g. 18',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 2. CLINICAL OBSERVATIONS & FIELD CARE
                  // ==========================================
                  const Text(
                    '2. Observed Symptoms & Field Care Advice',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: symptomsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Patient Symptoms',
                      hintText: 'Enter observed symptoms...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: observationsController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Physical Examination Findings',
                      hintText: 'Chest clear, mild pallor, edema...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fieldCareController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Field Care / OTC Guidance & Instructions',
                      hintText: 'Prescribe OTC hydration, rest, or dietary adjustment...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // 3. DECISION SELECTION
                  // ==========================================
                  const Text(
                    '3. Clinical Decision',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => decisionMode = 'manage'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: decisionMode == 'manage' ? const Color(0xFFECFDF5) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: decisionMode == 'manage' ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                width: decisionMode == 'manage' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.healing_rounded, color: decisionMode == 'manage' ? const Color(0xFF059669) : const Color(0xFF64748B), size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage in Field',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: decisionMode == 'manage' ? const Color(0xFF065F46) : const Color(0xFF334155),
                                  ),
                                ),
                                Text(
                                  'OTC care & home monitoring',
                                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => decisionMode = 'refer'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: decisionMode == 'refer' ? const Color(0xFFEDE9FE) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: decisionMode == 'refer' ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                                width: decisionMode == 'refer' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.send_rounded, color: decisionMode == 'refer' ? const Color(0xFF7C3AED) : const Color(0xFF64748B), size: 24),
                                const SizedBox(height: 4),
                                Text(
                                  'Refer to Doctor',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: decisionMode == 'refer' ? const Color(0xFF5B21B6) : const Color(0xFF334155),
                                  ),
                                ),
                                Text(
                                  'Book specialist slot (Max 3/slot)',
                                  style: TextStyle(fontSize: 9.5, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ==========================================
                  // REFERRAL DETAILS FORM (IF REFER SELECTED)
                  // ==========================================
                  if (decisionMode == 'refer') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Referral Doctor & Slot Booking',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 8),

                          // Select Doctor
                          DropdownButtonFormField<String>(
                            value: selectedDoctorId,
                            decoration: InputDecoration(
                              labelText: 'Select Specialist Doctor',
                              filled: true,
                              fillColor: Colors.white,
                              prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF0F766E), size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: doctorsList.map((d) {
                              final docId = d['user_id']?.toString() ?? '';
                              final docName = d['full_name']?.toString() ?? 'Doctor';
                              final specList = d['specialties'] is List ? (d['specialties'] as List).join(', ') : '';
                              return DropdownMenuItem<String>(
                                value: docId,
                                child: Text(specList.isNotEmpty ? '$docName ($specList)' : docName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) => setModalState(() => selectedDoctorId = val),
                          ),
                          const SizedBox(height: 10),

                          // Consultation Type: Telehealth vs Clinic
                          Row(
                            children: [
                              _buildTypeChoiceChip(
                                label: 'Telehealth Consultation',
                                icon: Icons.videocam_rounded,
                                typeKey: 'telehealth',
                                selectedType: selectedConsultationType,
                                onTap: () => setModalState(() => selectedConsultationType = 'telehealth'),
                              ),
                              const SizedBox(width: 8),
                              _buildTypeChoiceChip(
                                label: 'In-Person Hospital Visit',
                                icon: Icons.local_hospital_rounded,
                                typeKey: 'clinic',
                                selectedType: selectedConsultationType,
                                onTap: () => setModalState(() => selectedConsultationType = 'clinic'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 30-Minute Time Slot Picker with Live Capacity Check
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Select 30-Min Slot (Max 3/slot):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              TextButton(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) {
                                    setModalState(() => selectedDate = picked);
                                  }
                                },
                                child: Text(
                                  'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: timeSlots.map((slot) {
                              // Calculate how many patients currently booked in this slot
                              final countInSlot = _patientAppointments.where((a) {
                                final isSameSlot = a.timing.contains(slot.split(' - ').first);
                                final isNotCancelled = a.status.toLowerCase() != 'cancelled';
                                return isSameSlot && isNotCancelled;
                              }).length;

                              final spotsRemaining = 3 - countInSlot;
                              final isFull = spotsRemaining <= 0;
                              final isSelected = selectedSlot == slot;

                              return InkWell(
                                onTap: isFull
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('This 30-minute slot is FULL (Maximum 3 patients reached). Please pick another slot.'),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    : () => setModalState(() => selectedSlot = slot),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0F766E)
                                        : (isFull ? const Color(0xFFF1F5F9) : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF0F766E)
                                          : (isFull ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8)),
                                      width: isSelected ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        slot,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : (isFull ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isFull ? 'FULL' : '$spotsRemaining / 3 spots available',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFFCCFBF1)
                                              : (isFull ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),

                          TextField(
                            controller: referralReasonController,
                            decoration: InputDecoration(
                              labelText: 'Referral Reason / Specialist Note',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SUBMIT ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              // 1. Build and validate vitals map (omitting empty fields)
                              final vitalsMap = <String, dynamic>{};

                              if (hrController.text.trim().isNotEmpty) {
                                final hr = num.tryParse(hrController.text.trim());
                                if (hr == null || hr < 30 || hr > 250) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Heart Rate. Must be between 30 and 250 BPM.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['heart_rate_bpm'] = hr;
                              }

                              if (bpSysController.text.trim().isNotEmpty || bpDiaController.text.trim().isNotEmpty) {
                                final sys = num.tryParse(bpSysController.text.trim());
                                final dia = num.tryParse(bpDiaController.text.trim());
                                if (sys == null || sys < 50 || sys > 260 || dia == null || dia < 30 || dia > 160) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Blood Pressure. Systolic (50-260), Diastolic (30-160).'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['blood_pressure'] = '$sys/$dia';
                                vitalsMap['blood_pressure_systolic'] = sys;
                                vitalsMap['blood_pressure_diastolic'] = dia;
                              }

                              if (spo2Controller.text.trim().isNotEmpty) {
                                final spo2 = num.tryParse(spo2Controller.text.trim());
                                if (spo2 == null || spo2 < 50 || spo2 > 100) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid SpO2. Must be between 50 and 100%.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['spo2_percent'] = spo2;
                              }

                              if (tempController.text.trim().isNotEmpty) {
                                final temp = num.tryParse(tempController.text.trim());
                                if (temp == null || temp < 30 || temp > 45) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Temperature. Must be between 30 and 45 °C.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['temperature_c'] = temp;
                              }

                              if (glucoseController.text.trim().isNotEmpty) {
                                final glu = num.tryParse(glucoseController.text.trim());
                                if (glu == null || glu < 20 || glu > 800) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Glucose reading. Must be between 20 and 800 mg/dL.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['blood_glucose_mg_dl'] = glu;
                              }

                              if (weightController.text.trim().isNotEmpty) {
                                final wt = num.tryParse(weightController.text.trim());
                                if (wt == null || wt < 1 || wt > 300) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Weight. Must be between 1 and 300 kg.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['weight_kg'] = wt;
                              }

                              if (rrController.text.trim().isNotEmpty) {
                                final rr = num.tryParse(rrController.text.trim());
                                if (rr == null || rr < 4 || rr > 80) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Invalid Respiratory Rate. Must be between 4 and 80.'), backgroundColor: Colors.redAccent),
                                  );
                                  return;
                                }
                                vitalsMap['respiratory_rate'] = rr;
                              }

                              setModalState(() => isSubmitting = true);

                              try {
                                // 2. Create triage medical record on PostgreSQL
                                final clinicalDataPayload = {
                                  'assessment_type': 'asha_assessment',
                                  'decision': decisionMode == 'refer' ? 'referred_to_doctor' : 'managed',
                                  'vitals': vitalsMap,
                                  'symptoms': symptomsController.text.trim(),
                                  'observations': observationsController.text.trim(),
                                  'field_care_advice': fieldCareController.text.trim(),
                                  'asha_appointment_id': ashaReq?.id,
                                  'recorded_at': DateTime.now().toIso8601String(),
                                };

                                final recordRes = await ApiClient.createMedicalRecord(
                                  patientId: widget.patient.id,
                                  recordType: 'triage',
                                  clinicalData: clinicalDataPayload,
                                );

                                final recordData = recordRes['data'] is Map ? recordRes['data'] as Map : {};
                                final recordId = recordData['medical_record_id']?.toString() ?? recordData['record_id']?.toString();

                                if (decisionMode == 'manage') {
                                  // Update ASHA request to completed with managed_in_field
                                  if (ashaReq != null) {
                                    await ApiClient.updateAppointment(
                                      appointmentId: ashaReq.id,
                                      status: 'completed',
                                      notes: {
                                        'resolution': 'managed_in_field',
                                        'managed_at': DateTime.now().toIso8601String(),
                                        'asha_assessment_id': recordId,
                                      },
                                    );
                                  }

                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  _loadPatientMedicalRecords();
                                  _loadPatientAppointments();
                                  widget.onAppointmentCreated?.call();

                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 26),
                                          SizedBox(width: 8),
                                          Text('Case Managed in Field'),
                                        ],
                                      ),
                                      content: Text(
                                        'ASHA assessment & field care advice for ${widget.patient.name} recorded to medical records.',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                } else {
                                  // Refer to Doctor: parse slot timing safely (e.g. '10:00 - 10:30 AM' or '02:00 - 02:30 PM')
                                  final isPm = selectedSlot.toUpperCase().contains('PM');
                                  final slotParts = selectedSlot.split(' - ');
                                  final timeStr = slotParts.first.trim();
                                  final timeComponents = timeStr.split(':');
                                  int hour = int.tryParse(timeComponents[0]) ?? 10;
                                  int min = timeComponents.length > 1
                                      ? (int.tryParse(timeComponents[1].replaceAll(RegExp(r'\D'), '')) ?? 0)
                                      : 0;

                                  if (isPm && hour < 12) {
                                    hour += 12;
                                  } else if (!isPm && hour == 12) {
                                    hour = 0;
                                  }

                                  final scheduledStart = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    hour,
                                    min,
                                  );

                                  final apptRes = await ApiClient.createAppointment(
                                    patientId: widget.patient.id,
                                    doctorUserId: selectedDoctorId!,
                                    appointmentType: selectedConsultationType,
                                    scheduledStart: scheduledStart,
                                    status: 'confirmed',
                                    reason: referralReasonController.text.trim().isNotEmpty
                                        ? referralReasonController.text.trim()
                                        : 'ASHA Clinical Referral',
                                    notes: {
                                      'referral_type': 'asha_referral',
                                      'asha_referral_id': ashaReq?.id,
                                      'asha_assessment_id': recordId,
                                      'vitals': vitalsMap,
                                      'symptoms': symptomsController.text.trim(),
                                      'field_care_advice': fieldCareController.text.trim(),
                                      'slot_time': selectedSlot,
                                      'referred_by_worker_id': widget.userProfile?.userId,
                                      'referred_by_worker_name': widget.userProfile?.name ?? 'Healthcare Worker',
                                      'accepted_by_user_id': widget.userProfile?.userId,
                                      'accepted_by_name': widget.userProfile?.name ?? 'Healthcare Worker',
                                    },
                                  );

                                  if (apptRes['success'] == true) {
                                    final apptData = apptRes['data'] is Map ? apptRes['data'] as Map : {};
                                    final newApptId = apptData['appointment_id']?.toString() ?? apptData['id']?.toString();

                                    // Mark original request as completed (resolution: referred_to_doctor)
                                    if (ashaReq != null) {
                                      final origNotes = ashaReq.notes != null ? Map<String, dynamic>.from(ashaReq.notes!) : <String, dynamic>{};
                                      origNotes['resolution'] = 'referred_to_doctor';
                                      origNotes['referred_appointment_id'] = newApptId;
                                      origNotes['asha_assessment_id'] = recordId;
                                      origNotes['referred_by_worker_id'] = widget.userProfile?.userId;
                                      origNotes['referred_by_worker_name'] = widget.userProfile?.name ?? 'Healthcare Worker';
                                      origNotes['accepted_by_user_id'] ??= widget.userProfile?.userId;
                                      origNotes['accepted_by_name'] ??= widget.userProfile?.name ?? 'Healthcare Worker';

                                      await ApiClient.updateAppointment(
                                        appointmentId: ashaReq.id,
                                        status: 'completed',
                                        notes: origNotes,
                                      );
                                    }

                                    if (!mounted) return;
                                    Navigator.pop(ctx);
                                    _loadPatientAppointments();
                                    _loadPatientMedicalRecords();
                                    widget.onAppointmentCreated?.call();

                                    showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 26),
                                            SizedBox(width: 8),
                                            Text('Referred to Doctor!'),
                                          ],
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Doctor consultation confirmed for ${widget.patient.name}.'),
                                            const SizedBox(height: 8),
                                            Text('Slot: $selectedSlot on ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                                            Text('Mode: ${selectedConsultationType.toUpperCase()}'),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Doctor and Patient can view full assessment and vitals immediately.',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
                                        ],
                                      ),
                                    );
                                  } else {
                                    setModalState(() => isSubmitting = false);
                                    final err = apptRes['error']?.toString() ?? 'Failed to book consultation.';
                                    showDialog(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Row(
                                          children: [
                                            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
                                            SizedBox(width: 8),
                                            Text('Booking Failed'),
                                          ],
                                        ),
                                        content: Text(err),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                                        ],
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
                                        SizedBox(width: 8),
                                        Text('Error'),
                                      ],
                                    ),
                                    content: Text('Error: $e'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
                                    ],
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: decisionMode == 'refer' ? const Color(0xFF7C3AED) : const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              decisionMode == 'refer'
                                  ? 'Confirm Doctor Referral & Book Slot'
                                  : 'Save Field Care Assessment (Managed)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
