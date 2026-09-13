import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../models/appointment_model.dart';
import '../services/api_client.dart';

class PatientDetailScreen extends StatefulWidget {
  final HospitalAdminPatient patient;
  final UserProfile? userProfile;
  final VoidCallback? onAppointmentCreated;

  const PatientDetailScreen({
    super.key,
    required this.patient,
    this.userProfile,
    this.onAppointmentCreated,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _isLoadingAppointments = false;
  List<AppointmentItem> _patientAppointments = [];
  List<Map<String, dynamic>> _liveDoctors = [];
  List<Map<String, dynamic>> _liveFacilities = [];

  @override
  void initState() {
    super.initState();
    _loadPatientAppointments();
    _loadDoctorsAndFacilities();
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
}
