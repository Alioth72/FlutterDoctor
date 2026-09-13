import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../models/appointment_model.dart';
import 'qr_workflow_screen.dart';
import 'login_screen.dart';
import 'patient_detail_screen.dart';
import 'appointment_detail_screen.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const WorkerDashboardScreen({super.key, this.userProfile});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _hospitalId;
  late HospitalDetailInfo _hospital;
  bool _isOnFieldDuty = true;
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All', 'Appointments', 'Admitted', 'Forwarded'

  List<AppointmentItem> _liveAppointments = [];
  bool _isLoadingAppointments = false;
  bool _isLoadingPatients = false;

  @override
  void initState() {
    super.initState();
    _hospitalId = widget.userProfile?.hospitalId ?? 'hosp_1';
    _hospital = HospitalAdminRepository.getHospitalDetails(_hospitalId);
    _loadLivePatients();
    _loadLiveDoctors();
    _loadLiveAppointments();
  }

  Future<void> _loadLiveDoctors() async {
    try {
      final rawDocs = await ApiClient.getDoctors();
      if (!mounted) return;
      if (rawDocs.isNotEmpty) {
        final liveList = rawDocs.map<HospitalAdminStaffDoctor>((row) {
          final availability = row['availability'] is Map ? row['availability'] as Map : {};
          final specialties = row['specialties'] is List
              ? (row['specialties'] as List).map((e) => e.toString()).toList()
              : <String>[];
          final phone = row['phone_e164']?.toString() ?? '';
          final localDigits = phone.replaceAll(RegExp(r'\D'), '');

          String dept = specialties.isNotEmpty ? specialties.first : 'General Medicine';
          String qual = availability['qualification']?.toString() ??
              (specialties.length > 1 ? specialties[1] : 'MBBS, MD');
          String desig = availability['designation']?.toString() ?? 'Consultant Specialist';
          int expYears = num.tryParse(availability['experience_years']?.toString() ?? '8')?.toInt() ?? 8;

          return HospitalAdminStaffDoctor(
            id: row['user_id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
            name: row['full_name']?.toString() ?? 'Doctor',
            phone: localDigits.length >= 10 ? localDigits.substring(localDigits.length - 10) : localDigits,
            password: '',
            department: dept,
            qualification: qual,
            designation: desig,
            experienceYears: expYears,
            chamberNo: availability['chamber']?.toString() ?? 'Chamber 108',
            hospitalId: _hospitalId,
            hospitalName: _hospital.name,
            isOnDuty: row['is_active'] != false,
            shiftTiming: availability['shift']?.toString() ?? '08:00 AM - 02:00 PM',
            email: '${localDigits.length >= 10 ? localDigits.substring(localDigits.length - 10) : localDigits}@${_hospital.name.toLowerCase().replaceAll(' ', '')}.org',
            licenseNumber: row['license_number']?.toString(),
          );
        }).toList();

        setState(() {
          HospitalAdminRepository.syncLiveDoctors(liveList, _hospitalId);
        });
      }
    } catch (e) {
      debugPrint('Error loading doctors in worker screen: $e');
    }
  }

  Future<void> _loadLivePatients() async {
    setState(() => _isLoadingPatients = true);
    try {
      final rawPatients = await ApiClient.getPatients();
      if (!mounted) return;
      if (rawPatients.isNotEmpty) {
        final liveList = rawPatients.map<HospitalAdminPatient>((row) {
          final phone = row['phone_e164']?.toString() ?? '';
          final localDigits = phone.replaceAll(RegExp(r'\D'), '');
          final dob = row['date_of_birth']?.toString();
          int age = 35;
          if (dob != null && dob.length >= 4) {
            final birthYear = int.tryParse(dob.substring(0, 4));
            if (birthYear != null) {
              age = DateTime.now().year - birthYear;
            }
          }
          final sex = row['sex_at_birth']?.toString();
          final formattedGender = (sex != null && sex.isNotEmpty)
              ? '${sex[0].toUpperCase()}${sex.substring(1)}'
              : 'Male';

          return HospitalAdminPatient(
            id: row['patient_id']?.toString() ?? 'pat_${DateTime.now().millisecondsSinceEpoch}',
            name: row['full_name']?.toString() ?? 'Patient',
            phone: localDigits.length >= 10 ? localDigits.substring(localDigits.length - 10) : localDigits,
            password: '••••',
            age: age,
            gender: formattedGender,
            diagnosis: 'Outpatient Care',
            department: 'General Medicine',
            hospitalId: _hospitalId,
            hospitalName: _hospital.name,
            roomNo: 'OPD Ward',
            bedNo: 'Bay 1',
            isAdmitted: false,
            assignedDoctor: row['assigned_doctor_name']?.toString() ?? 'Unassigned',
            assignedDoctorUserId: row['assigned_doctor_user_id']?.toString(),
            admissionDate: (row['created_at']?.toString() ?? '').split('T').first,
            medicalRecordNumber: row['medical_record_number']?.toString() ?? 'MRN-N/A',
            bloodGroup: row['blood_group']?.toString() ?? 'N/A',
          );
        }).toList();

        setState(() {
          HospitalAdminRepository.syncLivePatients(liveList, _hospitalId);
          _isLoadingPatients = false;
        });
      } else {
        setState(() => _isLoadingPatients = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  Future<void> _loadLiveAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final list = await ApiClient.getAppointments();
      if (!mounted) return;
      setState(() {
        if (list != null) {
          _liveAppointments = list;
        }
        _isLoadingAppointments = false;
      });
    } catch (e) {
      debugPrint('Error loading appointments in worker screen: $e');
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final patients = HospitalAdminRepository.getPatients(_hospitalId);
    final workerName = widget.userProfile?.name ?? 'Worker Sunita Devi';
    final workerRole = widget.userProfile?.designation ?? 'Primary Field Healthcare Worker';

    // Filter patients
    final filteredPatients = patients.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery) ||
          p.diagnosis.toLowerCase().contains(_searchQuery) ||
          p.phone.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_activeFilter == 'Admitted') return p.isAdmitted;
      if (_activeFilter == 'Forwarded') return p.forwardedToDoctor != null;
      return true;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildWorkerDrawer(workerName, workerRole),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 140.0,
              floating: true,
              pinned: false,
              snap: false,
              backgroundColor: const Color(0xFF0F766E),
              elevation: 4,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF115E59), Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu, size: 28, color: Colors.white),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                tooltip: 'Open Menu',
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _hospital.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2DD4BF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'WORKER MODE',
                                            style: TextStyle(
                                              color: Color(0xFF115E59),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Primary Healthcare & Field Unit',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // QR Scanner quick button
                              IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 26),
                                tooltip: 'Scan Patient QR',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const QrWorkflowScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Worker Badge & Duty Status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.badge_rounded, color: Color(0xFF0F766E), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workerName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        workerRole,
                                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.85)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isOnFieldDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isOnFieldDuty ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isOnFieldDuty ? 'ON FIELD DUTY' : 'OFF DUTY',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search patients by name, symptoms, phone...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Filter Chips: All | Appointments | Inpatient | Forwarded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Patients (${patients.length})', 'All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Appointments (${_liveAppointments.length})', 'Appointments'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Admitted (${patients.where((p) => p.isAdmitted).length})', 'Admitted'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Forwarded (${patients.where((p) => p.forwardedToDoctor != null).length})', 'Forwarded'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Patient List or Appointments List
            Expanded(
              child: _activeFilter == 'Appointments'
                  ? _buildAppointmentsTab()
                  : (filteredPatients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_search_rounded, size: 54, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              const Text(
                                'No patients found in your field roster',
                                style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            await Future.wait([
                              _loadLivePatients(),
                              _loadLiveAppointments(),
                              _loadLiveDoctors(),
                            ]);
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: filteredPatients.length,
                            itemBuilder: (context, index) {
                              final pat = filteredPatients[index];
                              return _buildPatientCard(pat);
                            },
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // APPOINTMENTS TAB FOR WORKER
  // ==========================================
  Widget _buildAppointmentsTab() {
    if (_isLoadingAppointments) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F766E)),
      );
    }

    if (_liveAppointments.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadLivePatients(),
            _loadLiveAppointments(),
            _loadLiveDoctors(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_outlined, size: 56, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Appointments Scheduled Yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a patient from "All Patients" and tap "Schedule Consultation" to book an appointment with a specialist doctor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _activeFilter = 'All'),
                    icon: const Icon(Icons.people_alt_rounded, size: 18, color: Colors.white),
                    label: const Text('View All Patients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadLivePatients(),
          _loadLiveAppointments(),
          _loadLiveDoctors(),
        ]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _liveAppointments.length,
        itemBuilder: (context, index) {
          final appt = _liveAppointments[index];
          final isConfirmed = appt.status.toLowerCase() == 'confirmed';
          final isQueued = appt.status.toLowerCase() == 'queued';

          Color statusBg = const Color(0xFFF1F5F9);
          Color statusTextColor = const Color(0xFF475569);
          if (isConfirmed) {
            statusBg = const Color(0xFFECFDF5);
            statusTextColor = const Color(0xFF059669);
          } else if (isQueued) {
            statusBg = const Color(0xFFFFFBEB);
            statusTextColor = const Color(0xFFD97706);
          } else if (appt.status.toLowerCase() == 'in_progress') {
            statusBg = const Color(0xFFEFF6FF);
            statusTextColor = const Color(0xFF2563EB);
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentDetailScreen(appointment: appt),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: APT No & Status
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
                              child: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              appt.appointmentNo.isNotEmpty ? appt.appointmentNo : appt.id,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appt.status.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusTextColor),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Color(0xFFF1F5F9)),

                    // Patient & Doctor Info
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFF1F5F9),
                          child: Icon(Icons.person_rounded, color: Color(0xFF0F766E), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appt.patientName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              if (appt.doctorName != null && appt.doctorName!.isNotEmpty)
                                Text(
                                  'Doctor: ${appt.doctorName}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA), fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Timing & Reason
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          appt.timing,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        if (appt.diagnosis.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appt.diagnosis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // PATIENT CARD FOR WORKER
  // ==========================================
  Widget _buildPatientCard(HospitalAdminPatient pat) {
    final hasForward = pat.forwardedToDoctor != null;

    // Check if patient has any active appointment in _liveAppointments
    final activeAppt = _liveAppointments.where((a) {
      final matchId = a.patientId != null && a.patientId == pat.id;
      final matchName = a.patientName.trim().toLowerCase() == pat.name.trim().toLowerCase();
      final isActive = a.status.toLowerCase() == 'confirmed' ||
          a.status.toLowerCase() == 'queued' ||
          a.status.toLowerCase() == 'in_progress';
      return (matchId || matchName) && isActive;
    }).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: hasForward ? const Color(0xFF818CF8) : const Color(0xFFE2E8F0),
          width: hasForward ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientDetailScreen(
                patient: pat,
                userProfile: widget.userProfile,
                onAppointmentCreated: () {
                  _loadLiveAppointments();
                },
              ),
            ),
          );
          _loadLiveAppointments();
          _loadLivePatients();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: pat.gender == 'Male' ? const Color(0xFFE0F2FE) : const Color(0xFFFCE7F3),
                    child: Icon(
                      pat.gender == 'Male' ? Icons.male_rounded : Icons.female_rounded,
                      color: pat.gender == 'Male' ? const Color(0xFF0284C7) : const Color(0xFFDB2777),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                pat.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pat.isAdmitted ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pat.isAdmitted ? 'INPATIENT' : 'FIELD / OPD',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pat.age} Yrs • ${pat.gender} • ${pat.department}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Text(
                          pat.diagnosis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Chevron indicator indicating patient is clickable
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),

              // Active Appointment Status Badge if any
              if (activeAppt != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Active Appt: ${activeAppt.status.toUpperCase()} with ${activeAppt.doctorName ?? "Doctor"} (${activeAppt.timing})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Vitals Chips
              if (pat.vitals != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: pat.vitals!.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ],

              // If forwarded, display prominent referral badge
              if (hasForward) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFF4338CA), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Forwarded to ${pat.forwardedToDoctor}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF312E81),
                              ),
                            ),
                            Text(
                              'Specialty: ${pat.forwardSpecialty ?? pat.department} • Urgency: ${pat.urgency ?? "Routine"}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5)),
                            ),
                            if (pat.forwardReason != null)
                              Text(
                                'Reason: ${pat.forwardReason}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const Divider(height: 14, color: Color(0xFFF1F5F9)),

              // WORKER ACTIONS:
              // 1. SCHEDULE CONSULTATION / PATIENT DETAILS
              // 2. PRESCRIBE RX
              // 3. FORWARD TO SPECIALIST DOCTOR
              Row(
                children: [
                  // Schedule Consult / Patient Details
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PatientDetailScreen(
                              patient: pat,
                              userProfile: widget.userProfile,
                              onAppointmentCreated: () {
                                _loadLiveAppointments();
                              },
                            ),
                          ),
                        );
                        _loadLiveAppointments();
                        _loadLivePatients();
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'Schedule Consult',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // In-Person Prescription Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openInPersonPrescriptionDialog(pat),
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0F766E)),
                      label: const Text(
                        'Prescribe Rx',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                        side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Forward to Specialist Doctor Button
                  InkWell(
                    onTap: () => _openForwardPatientModal(pat),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: const Icon(Icons.forward_to_inbox_rounded, size: 18, color: Color(0xFF4338CA)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 1. IN-PERSON PRESCRIPTION WORKFLOW
  // ==============================================================
  void _openInPersonPrescriptionDialog(HospitalAdminPatient pat) {
    final medCtrl = TextEditingController(text: 'Paracetamol 500mg, ORS Hydration Pack');
    final dosageCtrl = TextEditingController(text: '1 Tablet twice daily after food');
    final durationCtrl = TextEditingController(text: '5 Days');
    final notesCtrl = TextEditingController(text: 'Adequate hydration, warm water rest');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Color(0xFF0F766E)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'In-Person Prescription: ${pat.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Patient: ${pat.name} (${pat.age} Yrs, ${pat.gender})\nDiagnosis: ${pat.diagnosis}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: medCtrl,
                decoration: const InputDecoration(labelText: 'Prescribed Medicines / In-Person Field Rx'),
              ),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Dosage / Instructions'),
              ),
              TextField(
                controller: durationCtrl,
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Field Care Instructions & Diet'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0F766E),
                  content: Text('In-person prescription issued successfully for ${pat.name}!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text('Issue In-Person Rx', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 2. FORWARD PATIENT TO SPECIALIST DOCTOR WORKFLOW
  // "can only forward the patient to the next doctor who is better in that field"
  // ==============================================================
  void _openForwardPatientModal(HospitalAdminPatient pat) {
    final allDoctors = HospitalAdminRepository.getAllDoctors();
    String selectedSpecialty = pat.department;
    HospitalAdminStaffDoctor? selectedDoctor;

    // Filter doctors by initial specialty
    List<HospitalAdminStaffDoctor> getSpecialistDoctors(String specialty) {
      return allDoctors.where((d) => d.department.toLowerCase() == specialty.toLowerCase()).toList();
    }

    var specialistDocs = getSpecialistDoctors(selectedSpecialty);
    if (specialistDocs.isEmpty) {
      specialistDocs = allDoctors;
    }
    selectedDoctor = specialistDocs.first;

    final reasonCtrl = TextEditingController(
      text: 'Patient exhibits symptoms requiring advanced ${pat.department} consultation and specialized diagnostic tests.',
    );
    String selectedUrgency = 'Priority (Within 2 Hours)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.forward_to_inbox_rounded, color: Color(0xFF4338CA), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Forward Patient to Specialist',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Patient: ${pat.name} (${pat.diagnosis})',
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

                  // STEP 1: SELECT SPECIALTY FIELD
                  const Text(
                    '1. Select Specialist Field Needed',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _hospital.departments.contains(selectedSpecialty)
                        ? selectedSpecialty
                        : _hospital.departments.first,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _hospital.departments.map((dept) {
                      return DropdownMenuItem(value: dept, child: Text(dept));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedSpecialty = val;
                          final docs = getSpecialistDoctors(val);
                          specialistDocs = docs.isNotEmpty ? docs : allDoctors;
                          selectedDoctor = specialistDocs.first;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // STEP 2: SELECT SPECIALIST DOCTOR
                  const Text(
                    '2. Select Qualified Doctor in this Field',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),

                  ...specialistDocs.map((doc) {
                    final isSelected = selectedDoctor?.id == doc.id;
                    return InkWell(
                      onTap: () => setModalState(() => selectedDoctor = doc),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4338CA) : const Color(0xFFCBD5E1),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primaryLight,
                              child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        doc.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      if (doc.isOnDuty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'ON DUTY',
                                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '${doc.designation} • ${doc.qualification}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    '${doc.experienceYears} Years Exp • ${doc.chamberNo}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF4338CA)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // STEP 3: REASON & URGENCY
                  const Text(
                    '3. Referral Clinical Reason & Urgency',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Clinical Notes / Reason for Forwarding',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: selectedUrgency,
                    decoration: InputDecoration(
                      labelText: 'Referral Urgency Level',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Routine Referral', child: Text('Routine Referral')),
                      DropdownMenuItem(value: 'Priority (Within 2 Hours)', child: Text('Priority (Within 2 Hours)')),
                      DropdownMenuItem(value: 'Immediate Emergency Escalation', child: Text('Immediate Emergency Escalation')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedUrgency = val);
                    },
                  ),

                  const SizedBox(height: 20),

                  // CONFIRM FORWARD BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (selectedDoctor == null) return;

                        setState(() {
                          HospitalAdminRepository.forwardPatientToDoctor(
                            patientId: pat.id,
                            targetDoctorId: selectedDoctor!.id,
                            targetDoctorName: selectedDoctor!.name,
                            specialty: selectedSpecialty,
                            reason: reasonCtrl.text.trim(),
                            urgency: selectedUrgency,
                            forwardedByWorker: widget.userProfile?.name ?? 'Worker Sunita Devi',
                          );
                        });

                        Navigator.pop(ctx);

                        // Show Forwarded Confirmation Alert Dialog
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                                SizedBox(width: 10),
                                Text('Patient Forwarded!'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient ${pat.name} has been successfully referred and forwarded to:',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedDoctor!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF312E81)),
                                      ),
                                      Text(
                                        '${selectedDoctor!.designation} (${selectedSpecialty})',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF4338CA)),
                                      ),
                                      Text(
                                        'Chamber: ${selectedDoctor!.chamberNo}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Referral Token: REF-${pat.id.hashCode.abs() % 90000 + 10000}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('OK, Done', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: Text(
                        'Forward to ${selectedDoctor?.name ?? "Doctor"}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
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

  // ==========================================
  // WORKER DRAWER
  // ==========================================
  Widget _buildWorkerDrawer(String workerName, String workerRole) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF115E59), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.badge_rounded, color: Color(0xFF0F766E), size: 32),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        workerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        workerRole,
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF0F766E)),
              title: const Text('Field Patients Roster'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F766E)),
              title: const Text('Scan Patient QR'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QrWorkflowScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: Color(0xFF0F766E)),
              title: const Text('My Field Duty Shift'),
              subtitle: const Text('07:30 AM - 03:30 PM (Ward A & Field)'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(
                _isOnFieldDuty ? Icons.check_circle_outline : Icons.pause_circle_outline,
                color: _isOnFieldDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
              ),
              title: const Text('Toggle Field Duty Status'),
              trailing: Switch(
                value: _isOnFieldDuty,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() => _isOnFieldDuty = val);
                  Navigator.pop(context);
                },
              ),
            ),

            const Spacer(),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text('Logout', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              onTap: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
