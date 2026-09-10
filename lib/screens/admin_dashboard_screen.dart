import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../models/room_machine_models.dart';
import '../models/appointment_model.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const AdminDashboardScreen({super.key, this.userProfile});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _hospitalId;
  late HospitalDetailInfo _hospital;

  // Staff sub-tab: 0 = Doctors, 1 = Workers, 2 = Patients, 3 = Consultations
  int _staffSubTabIndex = 0;
  String _searchQuery = '';
  final Set<String> _visiblePasswords = {};
  bool _isLoadingDoctors = false;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  List<AppointmentItem> _liveAppointments = [];
  String _appointmentFilterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hospitalId = widget.userProfile?.hospitalId ?? 'hosp_1';
    _refreshHospitalData();
    _loadLiveDoctors();
    _loadLivePatients();
    _loadLiveAppointments();
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
    } catch (_) {
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _loadLiveDoctors() async {
    setState(() => _isLoadingDoctors = true);
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
          _isLoadingDoctors = false;
        });
      } else {
        setState(() => _isLoadingDoctors = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDoctors = false);
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
    } catch (e) {
      if (mounted) setState(() => _isLoadingPatients = false);
    }
  }

  void _refreshHospitalData() {
    setState(() {
      _hospital = HospitalAdminRepository.getHospitalDetails(_hospitalId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility(String id) {
    setState(() {
      if (_visiblePasswords.contains(id)) {
        _visiblePasswords.remove(id);
      } else {
        _visiblePasswords.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final doctors = HospitalAdminRepository.getDoctors(_hospitalId);
    final workers = HospitalAdminRepository.getWorkers(_hospitalId);
    final patients = HospitalAdminRepository.getPatients(_hospitalId);
    final shifts = HospitalAdminRepository.getShifts(_hospitalId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(doctors.length, workers.length, patients.length),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStaffAndPatientsTab(doctors, workers, patients),
          _buildShiftMonitoringTab(shifts, doctors, workers),
          _buildHospitalDetailsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Staff & Patients'),
            Tab(icon: Icon(Icons.access_time_filled_rounded), text: 'Shift Monitor'),
            Tab(icon: Icon(Icons.local_hospital_rounded), text: 'Hospital Info'),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int docCount, int workerCount, int patientCount) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(135),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x334338CA),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 24,
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
                                  _hospital.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ADMIN PORTAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Admin: ${_hospital.adminName} (${_hospital.adminPhone})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: () async {
                        await AuthService.logout();
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Quick Summary Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat('Doctors', '$docCount Active', Icons.medical_services_rounded),
                      Container(width: 1, height: 20, color: Colors.white24),
                      _buildHeaderStat('Workers', '$workerCount Field', Icons.badge_rounded),
                      Container(width: 1, height: 20, color: Colors.white24),
                      _buildHeaderStat('Patients', '$patientCount Total', Icons.personal_injury_rounded),
                      Container(width: 1, height: 20, color: Colors.white24),
                      _buildHeaderStat('Beds', '${_hospital.occupiedBeds}/${_hospital.totalBeds}', Icons.hotel_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: STAFF & PATIENTS DATABASE (CRUD)
  // ==========================================
  Widget _buildStaffAndPatientsTab(
    List<HospitalAdminStaffDoctor> doctors,
    List<HospitalAdminStaffWorker> workers,
    List<HospitalAdminPatient> patients,
  ) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Sub-Tab Switcher: Doctors | Workers | Patients | Consultations
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSubTabChip(
                  index: 0,
                  label: 'Doctors (${doctors.length})',
                  icon: Icons.medical_services_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _buildSubTabChip(
                  index: 1,
                  label: 'Workers (${workers.length})',
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF0D9488),
                ),
                const SizedBox(width: 8),
                _buildSubTabChip(
                  index: 2,
                  label: 'Patients (${patients.length})',
                  icon: Icons.personal_injury_outlined,
                  color: const Color(0xFFE11D48),
                ),
                const SizedBox(width: 8),
                _buildSubTabChip(
                  index: 3,
                  label: 'Consultations (${_liveAppointments.length})',
                  icon: Icons.event_note_rounded,
                  color: const Color(0xFF059669),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar & Action Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: _staffSubTabIndex == 0
                        ? 'Search doctors by name or phone...'
                        : _staffSubTabIndex == 1
                            ? 'Search workers by name or phone...'
                            : _staffSubTabIndex == 2
                                ? 'Search patients by name or diagnosis...'
                                : 'Search consultations by patient, reason, or ID...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_staffSubTabIndex == 3)
                ElevatedButton.icon(
                  onPressed: _loadLiveAppointments,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Refresh',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    if (_staffSubTabIndex == 0) {
                      _openAddDoctorDialog();
                    } else if (_staffSubTabIndex == 1) {
                      _openAddWorkerDialog();
                    } else {
                      _openAddPatientDialog();
                    }
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(
                    _staffSubTabIndex == 0
                        ? 'Add Doctor'
                        : _staffSubTabIndex == 1
                            ? 'Add Worker'
                            : 'Add Patient',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _staffSubTabIndex == 0
                        ? AppColors.primary
                        : _staffSubTabIndex == 1
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // List Content
        Expanded(
          child: _staffSubTabIndex == 0
              ? _buildDoctorsList(doctors)
              : _staffSubTabIndex == 1
                  ? _buildWorkersList(workers)
                  : _staffSubTabIndex == 2
                      ? _buildPatientsList(patients)
                      : _buildConsultationsList(),
        ),
      ],
    );
  }

  Widget _buildSubTabChip({
    required int index,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _staffSubTabIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _staffSubTabIndex = index;
        _searchQuery = '';
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DOCTORS LIST ---
  Widget _buildDoctorsList(List<HospitalAdminStaffDoctor> doctors) {
    final filtered = doctors.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_searchQuery) ||
          d.phone.contains(_searchQuery) ||
          d.department.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _isLoadingDoctors
          ? const Center(child: CircularProgressIndicator())
          : _buildEmptyState('No doctors found in ${_hospital.name}');
    }

    return RefreshIndicator(
      onRefresh: _loadLiveDoctors,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final doc = filtered[index];

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${doc.designation} • ${doc.department}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              doc.qualification,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 22),
                            tooltip: 'Edit Doctor Profile',
                            onPressed: () => _openEditDoctorDialog(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                            tooltip: 'Remove Doctor from Database',
                            onPressed: () => _confirmRemoveDoctor(doc),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),

                  // Details Grid: Chamber, Shift, Duty Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(Icons.meeting_room_outlined, 'Chamber: ${doc.chamberNo}'),
                            const SizedBox(height: 4),
                            _buildDetailRow(Icons.schedule_outlined, 'Shift: ${doc.shiftTiming}'),
                            const SizedBox(height: 4),
                            _buildDetailRow(Icons.phone_outlined, 'Phone: +91 ${doc.phone}'),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Duty Toggle Switch
                          Row(
                            children: [
                              Text(
                                doc.isOnDuty ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: doc.isOnDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                ),
                              ),
                              Switch(
                                value: doc.isOnDuty,
                                activeThumbColor: const Color(0xFF10B981),
                                onChanged: (val) async {
                                  setState(() {
                                    doc.isOnDuty = val;
                                    HospitalAdminRepository.updateDoctor(doc);
                                  });
                                  await ApiClient.updateDoctor(userId: doc.id, isActive: val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Verified License & Department Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'License: ${doc.licenseNumber?.isNotEmpty == true ? doc.licenseNumber : "Verified Practitioner"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Text(
                            doc.department,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkersList(List<HospitalAdminStaffWorker> workers) {
    final filtered = workers.where((w) {
      if (_searchQuery.isEmpty) return true;
      return w.name.toLowerCase().contains(_searchQuery) ||
          w.phone.contains(_searchQuery) ||
          w.assignedWard.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('No healthcare workers found in ${_hospital.name}');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final worker = filtered[index];
        final isPassVisible = _visiblePasswords.contains(worker.id);

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFCCFBF1),
                      child: const Icon(Icons.badge_rounded, color: Color(0xFF0D9488), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            worker.designation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            worker.qualification,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Remove Worker from Database',
                      onPressed: () => _confirmRemoveWorker(worker),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.local_hospital_outlined, 'Ward: ${worker.assignedWard}'),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.schedule_outlined, 'Shift: ${worker.shiftTiming}'),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.phone_outlined, 'Phone: ${worker.phone}'),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          worker.isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: worker.isOnDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                        ),
                        Switch(
                          value: worker.isOnDuty,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            setState(() {
                              HospitalAdminRepository.toggleStaffDuty(worker.id, false);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Worker Password Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, size: 16, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Text(
                        'Password: ${isPassVisible ? worker.password : '••••••••'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _togglePasswordVisibility(worker.id),
                        child: Text(
                          isPassVisible ? 'Hide' : 'Show',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- PATIENTS LIST ---
  Widget _buildPatientsList(List<HospitalAdminPatient> patients) {
    final filtered = patients.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.phone.contains(q) ||
          p.diagnosis.toLowerCase().contains(q) ||
          (p.medicalRecordNumber != null && p.medicalRecordNumber!.toLowerCase().contains(q)) ||
          (p.bloodGroup != null && p.bloodGroup!.toLowerCase().contains(q));
    }).toList();

    if (filtered.isEmpty) {
      return _isLoadingPatients
          ? const Center(child: CircularProgressIndicator())
          : _buildEmptyState('No patients registered in ${_hospital.name}');
    }

    return RefreshIndicator(
      onRefresh: _loadLivePatients,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final pat = filtered[index];

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFFFE4E6),
                        child: const Icon(Icons.personal_injury_rounded, color: Color(0xFFE11D48), size: 28),
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
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pat.isAdmitted ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    pat.isAdmitted ? 'INPATIENT' : 'OPD',
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
                            const SizedBox(height: 2),
                            Text(
                              pat.diagnosis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFBE123C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669)),
                            tooltip: 'View Prescriptions & Medicines',
                            onPressed: () => _showPatientPrescriptionsDialog(pat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                            tooltip: 'Assign / Reassign Doctor',
                            onPressed: () => _showAssignDoctorDialog(pat),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                            tooltip: 'Remove Patient from Database',
                            onPressed: () => _confirmRemovePatient(pat),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 18, color: Color(0xFFF1F5F9)),

                  // Patient Details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(Icons.phone_outlined, 'Phone: +91 ${pat.phone}'),
                            const SizedBox(height: 4),
                            _buildDetailRow(Icons.calendar_today_outlined, 'Registered: ${pat.admissionDate}'),
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              Icons.medical_services_outlined,
                              'Assigned Doctor: ${pat.assignedDoctor}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Real Database Credentials (MRN & Blood Group Badges & Prescriptions)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 5),
                            Text(
                              'MRN: ${pat.medicalRecordNumber ?? 'MRN-N/A'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E40AF),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bloodtype_outlined, size: 15, color: Color(0xFFDC2626)),
                            const SizedBox(width: 5),
                            Text(
                              'Blood: ${pat.bloodGroup ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showPatientPrescriptionsDialog(pat),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.medication_rounded, size: 15, color: Color(0xFF059669)),
                              SizedBox(width: 5),
                              Text(
                                'Prescriptions',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
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
          );
        },
      ),
    );
  }

  Widget _buildConsultationsList() {
    if (_isLoadingAppointments && _liveAppointments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF059669)),
      );
    }

    final filtered = _liveAppointments.where((appt) {
      final q = _searchQuery;
      final matchesSearch = q.isEmpty ||
          appt.patientName.toLowerCase().contains(q) ||
          appt.appointmentNo.toLowerCase().contains(q) ||
          appt.diagnosis.toLowerCase().contains(q);

      final matchesStatus = _appointmentFilterStatus == 'all' ||
          appt.status.toLowerCase() == _appointmentFilterStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    final completedCount = _liveAppointments.where((a) => a.status.toLowerCase() == 'completed').length;
    final inProgressCount = _liveAppointments.where((a) => a.status.toLowerCase() == 'in_progress').length;
    final confirmedCount = _liveAppointments.where((a) => a.status.toLowerCase() == 'confirmed').length;

    return RefreshIndicator(
      onRefresh: _loadLiveAppointments,
      color: const Color(0xFF059669),
      child: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildConsultationFilterChip('all', 'All (${_liveAppointments.length})'),
                  const SizedBox(width: 8),
                  _buildConsultationFilterChip(
                    'completed',
                    'Completed ($completedCount)',
                    isCompletedBadge: true,
                  ),
                  const SizedBox(width: 8),
                  _buildConsultationFilterChip(
                    'in_progress',
                    'In Progress ($inProgressCount)',
                  ),
                  const SizedBox(width: 8),
                  _buildConsultationFilterChip(
                    'confirmed',
                    'Confirmed ($confirmedCount)',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState('No consultations found matching your current filter.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final appt = filtered[index];
                      final isCompleted = appt.status.toLowerCase() == 'completed';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: isCompleted ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isCompleted
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top status row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                          SizedBox(width: 5),
                                          Text(
                                            'COMPLETED CONSULTATION',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: appt.status == 'in_progress'
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: appt.status == 'in_progress'
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFFBFDBFE),
                                        ),
                                      ),
                                      child: Text(
                                        appt.status.toUpperCase(),
                                        style: TextStyle(
                                          color: appt.status == 'in_progress'
                                              ? const Color(0xFFB45309)
                                              : const Color(0xFF1E40AF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isCompleted
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFCBD5E1),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      appt.appointmentNo,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: isCompleted
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Patient name & info
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 19,
                                    backgroundColor: isCompleted
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFE2E8F0),
                                    child: Text(
                                      appt.patientName.isNotEmpty ? appt.patientName[0].toUpperCase() : 'P',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isCompleted
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          appt.patientName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Text(
                                          '${appt.gender} • ${appt.age} yrs • ${appt.timing}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 10),

                              // Clinical Diagnosis / Reason
                              _buildDetailRow(
                                Icons.medical_information_outlined,
                                'Reason: ${appt.diagnosis.isNotEmpty ? appt.diagnosis : 'Clinical Consultation'}',
                              ),
                              const SizedBox(height: 6),
                              _buildDetailRow(
                                Icons.payment_rounded,
                                'Billing: ${appt.paymentStatus}',
                              ),
                               const SizedBox(height: 10),

                              // Prescribed Medicines Preview
                              if (appt.medicines.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCompleted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCompleted ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medication_rounded,
                                            size: 15,
                                            color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF0284C7),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Prescribed Medicines (${appt.medicines.length}):',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isCompleted ? const Color(0xFF166534) : const Color(0xFF0369A1),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: appt.medicines.map((med) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          child: Text(
                                            '${med.name} • ${med.duration}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Actions Row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      'Mode: ${appt.mode.name.toUpperCase()}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      // View Full Prescription & Medicines Dialog
                                      OutlinedButton.icon(
                                        onPressed: () => _showPrescriptionDialog(appt),
                                        icon: const Icon(
                                          Icons.receipt_long_rounded,
                                          size: 16,
                                          color: Color(0xFF059669),
                                        ),
                                        label: const Text(
                                          'Prescription',
                                          style: TextStyle(
                                            color: Color(0xFF059669),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                                          backgroundColor: const Color(0xFFECFDF5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                      ),
                                      // Permanent Delete from Database (Admin only)
                                      OutlinedButton.icon(
                                        onPressed: () => _confirmDeleteConsultation(appt),
                                        icon: const Icon(
                                          Icons.delete_forever_rounded,
                                          size: 16,
                                          color: Color(0xFFDC2626),
                                        ),
                                        label: const Text(
                                          'Remove',
                                          style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                                          backgroundColor: const Color(0xFFFEF2F2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationFilterChip(String status, String label, {bool isCompletedBadge = false}) {
    final isSelected = _appointmentFilterStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isCompletedBadge ? const Color(0xFF15803D) : const Color(0xFF475569)),
        ),
      ),
      selected: isSelected,
      selectedColor: isCompletedBadge ? const Color(0xFF10B981) : const Color(0xFF0F172A),
      backgroundColor: isCompletedBadge ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isCompletedBadge ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
      ),
      onSelected: (_) {
        setState(() => _appointmentFilterStatus = status);
      },
    );
  }

  void _confirmDeleteConsultation(AppointmentItem appt) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Delete from Database',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Are you sure you want to permanently delete appointment ${appt.appointmentNo} for ${appt.patientName} from the database?\n\nThis action cannot be undone.',
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => isDeleting = true);
                          try {
                            final res = await ApiClient.deleteAppointment(appt.id);
                            if (res['success'] == true) {
                              if (mounted) {
                                setState(() {
                                  _liveAppointments.removeWhere((a) => a.id == appt.id);
                                });
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Consultation ${appt.appointmentNo} permanently deleted from database.',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              if (mounted) {
                                _loadLiveAppointments();
                                _loadLivePatients();
                              }
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete: ${res['error'] ?? 'Unknown error'}'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error deleting consultation: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          } finally {
                            if (ctx.mounted) setDialogState(() => isDeleting = false);
                          }
                        },
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18),
                  label: const Text('Delete from DB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPrescriptionDialog(AppointmentItem appt) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isCompleted = appt.status.toLowerCase() == 'completed';
        final medicines = appt.medicines;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  color: isCompleted ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prescription & Medicines',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${appt.appointmentNo} • ${appt.patientName}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Patient & Doctor summary card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Patient: ${appt.patientName} (${appt.age}y / ${appt.gender})',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                appt.status.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: isCompleted ? const Color(0xFF166534) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Doctor: ${appt.doctorName}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        if (appt.diagnosis.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.medical_information_outlined, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Diagnosis: ${appt.diagnosis}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Heading
                  Row(
                    children: [
                      const Icon(Icons.format_list_bulleted_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Text(
                        'Prescribed Medications (${medicines.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (medicines.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'No medications recorded for this consultation.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  else
                    ...medicines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final med = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
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
                                  child: Text(
                                    '${idx + 1}. ${med.name}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    med.duration,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Dosage / Frequency: ${med.dosage}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            if (med.closestClinic.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.local_pharmacy_outlined, size: 14, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Dispensing: ${med.closestClinic}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  if (appt.isAdmitted) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bed_rounded, size: 15, color: Color(0xFFDC2626)),
                              SizedBox(width: 6),
                              Text(
                                'Inpatient Care Details',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF991B1B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Room / Bed: ${appt.roomNo ?? 'General Ward'}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                          if (appt.dietarySuggestions != null && appt.dietarySuggestions!.isNotEmpty)
                            Text('Diet: ${appt.dietarySuggestions}', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPatientPrescriptionsDialog(HospitalAdminPatient pat) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: ApiClient.getPatientPrescriptions(pat.id),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final rxList = snapshot.data ?? [];

                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF059669),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Patient Prescriptions',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${pat.name} • MRN: ${pat.medicalRecordNumber ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 380,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                        : rxList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.medication_liquid_outlined, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No prescriptions recorded for ${pat.name}.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: rxList.length,
                                itemBuilder: (context, idx) {
                                  final rx = rxList[idx];
                                  final medName = rx['medication_name']?.toString() ?? 'Medication';
                                  final dosage = rx['dosage']?.toString() ?? rx['frequency']?.toString() ?? '1 tablet';
                                  final duration = rx['duration_days'] != null ? '${rx['duration_days']} Days' : '5 Days';
                                  final prescriber = rx['prescriber_name']?.toString() ?? 'Doctor';
                                  final status = rx['status']?.toString() ?? 'active';
                                  final pharmacy = rx['pharmacy_name']?.toString() ?? 'Ashwini Central Pharmacy';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${idx + 1}. $medName',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: status == 'active'
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  color: status == 'active'
                                                      ? const Color(0xFF15803D)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Dosage: $dosage • Duration: $duration',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Prescribed by: $prescriber',
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (pharmacy.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.local_pharmacy_outlined, size: 14, color: Color(0xFF059669)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Pharmacy: $pharmacy',
                                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: SHIFT MONITORING & MANAGEMENT
  // ==========================================
  Widget _buildShiftMonitoringTab(
    List<HospitalShiftItem> shifts,
    List<HospitalAdminStaffDoctor> doctors,
    List<HospitalAdminStaffWorker> workers,
  ) {
    final onDutyDocs = doctors.where((d) => d.isOnDuty).length;
    final onDutyWorkers = workers.where((w) => w.isOnDuty).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Duty Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 12,
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
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Shift Status',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$onDutyDocs Doctors On Duty  •  $onDutyWorkers Workers On Field',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAssignShiftDialog(doctors, workers),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Assign Shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF065F46),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Hospital Shift Roster',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Real-time shift schedules for ${_hospital.name}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          if (shifts.isEmpty)
            _buildEmptyState('No shifts scheduled for this hospital')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shifts.length,
              itemBuilder: (context, index) {
                final shift = shifts[index];
                final isDoctor = shift.staffRole == 'Doctor';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDoctor ? AppColors.primaryLight : const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDoctor ? Icons.medical_services_outlined : Icons.badge_outlined,
                          color: isDoctor ? AppColors.primary : const Color(0xFF0D9488),
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
                                  shift.staffName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDoctor ? AppColors.primary : const Color(0xFF0D9488),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    shift.staffRole.toUpperCase(),
                                    style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${shift.department} • ${shift.roomOrWard}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shift.timeSlot,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        tooltip: 'Remove Shift',
                        onPressed: () {
                          setState(() {
                            HospitalAdminRepository.removeShift(shift.id);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: HOSPITAL COMPLETE DETAILS
  // ==========================================
  Widget _buildHospitalDetailsTab() {
    final rooms = RoomMachineRepository.getAllRooms()
        .where((r) => r.hospitalId == _hospitalId)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hospital Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hospital.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _hospital.branch,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                _buildWhiteInfoRow(Icons.location_on_outlined, _hospital.address),
                const SizedBox(height: 6),
                _buildWhiteInfoRow(Icons.phone_outlined, 'Desk: ${_hospital.contactPhone}'),
                const SizedBox(height: 6),
                _buildWhiteInfoRow(Icons.emergency_outlined, 'Emergency: ${_hospital.emergencyHotline}'),
                const SizedBox(height: 6),
                _buildWhiteInfoRow(Icons.verified_user_outlined, 'License: ${_hospital.licenseNumber}'),
                const SizedBox(height: 6),
                _buildWhiteInfoRow(Icons.admin_panel_settings_outlined, 'Hospital Admin: ${_hospital.adminName}'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Bed Capacity & Occupancy Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bed_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Bed Capacity & Occupancy',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _hospital.totalBeds > 0 ? _hospital.occupiedBeds / _hospital.totalBeds : 0,
                    minHeight: 14,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_hospital.totalBeds} Beds',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    Text(
                      'Occupied: ${_hospital.occupiedBeds}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                    ),
                    Text(
                      'Available: ${_hospital.totalBeds - _hospital.occupiedBeds}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Hospital Departments
          const Text(
            'Hospital Departments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hospital.departments.map((dept) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      dept,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Rooms & Equipment Inventory for this Hospital
          const Text(
            'Rooms & Machinery Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Total ${rooms.length} registered room units in ${_hospital.name}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (rooms.isEmpty)
            _buildEmptyState('No room records configured for this hospital')
          else
            ...rooms.map((room) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${room.roomNumber}: ${room.roomName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.floor,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF4338CA), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Beds: ${room.occupiedBeds}/${room.totalBeds} Occupied  •  Equipments: ${room.equipments.length} Active',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    if (room.equipments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: room.equipments.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.name} (${e.status})',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWhiteInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ADD DOCTOR DIALOG (Phase 8: ApiClient Integration)
  // ==========================================
  void _openAddDoctorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'Doctor@12345');
    final licenseCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final desigCtrl = TextEditingController(text: 'Consultant Specialist');
    final expCtrl = TextEditingController(text: '8');
    final chamberCtrl = TextEditingController(text: 'Chamber 108');
    final shiftCtrl = TextEditingController(text: '08:00 AM - 02:00 PM');
    String selectedDept = _hospital.departments.first;
    bool obscurePass = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Add Doctor to Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Full Name *',
                    hintText: 'e.g. Dr. Ramesh Gupta',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Login ID) *',
                    hintText: '10 digits (e.g. 9811223344)',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Initial Password (Min 8 chars) *',
                    hintText: 'e.g. Doctor@12345',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medical License Number',
                    hintText: 'e.g. MCI-DEL-2026-4421',
                    prefixIcon: Icon(Icons.verified_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(
                    labelText: 'Department / Specialty',
                    prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                  ),
                  items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: isSubmitting ? null : (val) {
                    if (val != null) setDlgState(() => selectedDept = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qualCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qualification',
                    hintText: 'e.g. MBBS, MD, DM',
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    prefixIcon: Icon(Icons.work_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Exp (Years)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: chamberCtrl,
                        decoration: const InputDecoration(labelText: 'Chamber'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shiftCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Shift Timing',
                    prefixIcon: Icon(Icons.access_time, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final password = passCtrl.text.trim();
                      final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');

                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFE11D48),
                            content: Text('Please enter doctor full name'),
                          ),
                        );
                        return;
                      }

                      if (phoneDigits.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFE11D48),
                            content: Text('Please enter a valid 10-digit phone number'),
                          ),
                        );
                        return;
                      }

                      if (password.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFE11D48),
                            content: Text('Initial password must be at least 8 characters'),
                          ),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);

                      final specialties = [
                        selectedDept,
                        if (qualCtrl.text.trim().isNotEmpty) qualCtrl.text.trim(),
                      ];

                      final availability = {
                        'chamber': chamberCtrl.text.trim().isNotEmpty ? chamberCtrl.text.trim() : 'Chamber 108',
                        'shift': shiftCtrl.text.trim().isNotEmpty ? shiftCtrl.text.trim() : '08:00 AM - 02:00 PM',
                        'hospital_id': _hospitalId,
                        'qualification': qualCtrl.text.trim().isNotEmpty ? qualCtrl.text.trim() : 'MBBS, MD',
                        'designation': desigCtrl.text.trim().isNotEmpty ? desigCtrl.text.trim() : 'Consultant Specialist',
                        'experience_years': int.tryParse(expCtrl.text.trim()) ?? 8,
                      };

                      final res = await ApiClient.createDoctor(
                        fullName: name,
                        phone: phone,
                        password: password,
                        licenseNumber: licenseCtrl.text.trim().isNotEmpty ? licenseCtrl.text.trim() : null,
                        specialties: specialties,
                        availability: availability,
                      );

                      if (!mounted || !ctx.mounted) return;

                      if (res['success'] == true) {
                        final data = res['data'] is Map ? res['data'] as Map : {};
                        final newDoc = HospitalAdminStaffDoctor(
                          id: data['user_id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
                          name: data['full_name']?.toString() ?? (name.startsWith('Dr.') ? name : 'Dr. $name'),
                          phone: data['phone_e164']?.toString() ?? phone,
                          password: '',
                          department: selectedDept,
                          qualification: qualCtrl.text.trim().isNotEmpty ? qualCtrl.text.trim() : 'MBBS, MD',
                          designation: desigCtrl.text.trim().isNotEmpty ? desigCtrl.text.trim() : 'Consultant Specialist',
                          experienceYears: int.tryParse(expCtrl.text.trim()) ?? 5,
                          chamberNo: chamberCtrl.text.trim().isNotEmpty ? chamberCtrl.text.trim() : 'Chamber 108',
                          hospitalId: _hospitalId,
                          hospitalName: _hospital.name,
                          isOnDuty: true,
                          shiftTiming: shiftCtrl.text.trim().isNotEmpty ? shiftCtrl.text.trim() : '08:00 AM - 02:00 PM',
                          email: '${phoneDigits.length >= 10 ? phoneDigits.substring(phoneDigits.length - 10) : phoneDigits}@${_hospital.name.toLowerCase().replaceAll(' ', '')}.org',
                        );

                        setState(() {
                          HospitalAdminRepository.addDoctor(newDoc);
                        });

                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Doctor ${newDoc.name} successfully registered in database!')),
                              ],
                            ),
                          ),
                        );
                      } else {
                        setDlgState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFE11D48),
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text(res['error']?.toString() ?? 'Registration failed')),
                              ],
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Doctor', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EDIT DOCTOR DIALOG
  // ==========================================
  void _openEditDoctorDialog(HospitalAdminStaffDoctor doc) {
    final nameCtrl = TextEditingController(text: doc.name);
    final phoneCtrl = TextEditingController(text: doc.phone);
    final licenseCtrl = TextEditingController(text: doc.licenseNumber ?? '');
    final qualCtrl = TextEditingController(text: doc.qualification);
    final desigCtrl = TextEditingController(text: doc.designation);
    final expCtrl = TextEditingController(text: doc.experienceYears.toString());
    final chamberCtrl = TextEditingController(text: doc.chamberNo);
    final shiftCtrl = TextEditingController(text: doc.shiftTiming);
    String selectedDept = _hospital.departments.contains(doc.department)
        ? doc.department
        : (_hospital.departments.isNotEmpty ? _hospital.departments.first : 'General Medicine');
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Edit Doctor Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Doctor Full Name *',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Phone (Registered Identity)',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    filled: true,
                    fillColor: Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medical License Number',
                    hintText: 'e.g. MCI-DEL-2026-4421',
                    prefixIcon: Icon(Icons.verified_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(
                    labelText: 'Department / Specialty',
                    prefixIcon: Icon(Icons.medical_services_outlined, size: 20),
                  ),
                  items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: isSubmitting ? null : (val) {
                    if (val != null) setDlgState(() => selectedDept = val);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qualCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Qualification',
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    prefixIcon: Icon(Icons.work_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Exp (Years)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: chamberCtrl,
                        decoration: const InputDecoration(labelText: 'Chamber'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shiftCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Shift Timing',
                    prefixIcon: Icon(Icons.access_time, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFE11D48),
                            content: Text('Please enter doctor full name'),
                          ),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);

                      final specialties = [
                        selectedDept,
                        if (qualCtrl.text.trim().isNotEmpty) qualCtrl.text.trim(),
                      ];

                      final availability = {
                        'chamber': chamberCtrl.text.trim().isNotEmpty ? chamberCtrl.text.trim() : doc.chamberNo,
                        'shift': shiftCtrl.text.trim().isNotEmpty ? shiftCtrl.text.trim() : doc.shiftTiming,
                        'hospital_id': _hospitalId,
                        'qualification': qualCtrl.text.trim().isNotEmpty ? qualCtrl.text.trim() : doc.qualification,
                        'designation': desigCtrl.text.trim().isNotEmpty ? desigCtrl.text.trim() : doc.designation,
                        'experience_years': int.tryParse(expCtrl.text.trim()) ?? doc.experienceYears,
                      };

                      final res = await ApiClient.updateDoctor(
                        userId: doc.id,
                        fullName: name,
                        licenseNumber: licenseCtrl.text.trim().isNotEmpty ? licenseCtrl.text.trim() : null,
                        specialties: specialties,
                        availability: availability,
                      );

                      if (!mounted || !ctx.mounted) return;

                      if (res['success'] == true) {
                        doc.name = name.startsWith('Dr.') ? name : 'Dr. $name';
                        doc.department = selectedDept;
                        doc.qualification = qualCtrl.text.trim().isNotEmpty ? qualCtrl.text.trim() : doc.qualification;
                        doc.designation = desigCtrl.text.trim().isNotEmpty ? desigCtrl.text.trim() : doc.designation;
                        doc.experienceYears = int.tryParse(expCtrl.text.trim()) ?? doc.experienceYears;
                        doc.chamberNo = chamberCtrl.text.trim().isNotEmpty ? chamberCtrl.text.trim() : doc.chamberNo;
                        doc.shiftTiming = shiftCtrl.text.trim().isNotEmpty ? shiftCtrl.text.trim() : doc.shiftTiming;
                        doc.licenseNumber = licenseCtrl.text.trim().isNotEmpty ? licenseCtrl.text.trim() : null;

                        setState(() {
                          HospitalAdminRepository.updateDoctor(doc);
                        });

                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF10B981),
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Doctor ${doc.name} profile updated in database!')),
                              ],
                            ),
                          ),
                        );
                      } else {
                        setDlgState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFE11D48),
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(child: Text(res['error']?.toString() ?? 'Update failed')),
                              ],
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update Doctor', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // ADD WORKER DIALOG
  // ==========================================
  void _openAddWorkerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final qualCtrl = TextEditingController(text: 'ANM / Healthcare Specialist');
    final desigCtrl = TextEditingController(text: 'Primary Field Healthcare Worker');
    final wardCtrl = TextEditingController(text: 'Ward A & Field Clinic');
    final shiftCtrl = TextEditingController(text: '07:30 AM - 03:30 PM');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text('Add Healthcare Worker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Worker Full Name', hintText: 'e.g. Sunita Devi'),
              ),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (Login Username)'),
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password (Credentials)'),
              ),
              TextField(
                controller: qualCtrl,
                decoration: const InputDecoration(labelText: 'Qualification / Certification'),
              ),
              TextField(
                controller: desigCtrl,
                decoration: const InputDecoration(labelText: 'Designation / Field Role'),
              ),
              TextField(
                controller: wardCtrl,
                decoration: const InputDecoration(labelText: 'Assigned Ward / Community Unit'),
              ),
              TextField(
                controller: shiftCtrl,
                decoration: const InputDecoration(labelText: 'Shift Timing'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final pass = passCtrl.text.trim();

              if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill Name, Phone, and Password')),
                );
                return;
              }

              final newWorker = HospitalAdminStaffWorker(
                id: 'work_${DateTime.now().millisecondsSinceEpoch}',
                name: name.startsWith('Worker') ? name : 'Worker $name',
                phone: phone,
                password: pass,
                qualification: qualCtrl.text.trim(),
                designation: desigCtrl.text.trim(),
                assignedWard: wardCtrl.text.trim(),
                hospitalId: _hospitalId,
                hospitalName: _hospital.name,
                isOnDuty: true,
                shiftTiming: shiftCtrl.text.trim(),
                email: '${phone}@${_hospital.name.toLowerCase().replaceAll(' ', '')}.org',
              );

              setState(() {
                HospitalAdminRepository.addWorker(newWorker);
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0D9488),
                  content: Text('${newWorker.name} added to database!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Save Worker', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ADD PATIENT DIALOG
  // ==========================================
  void _openAddPatientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final mrnCtrl = TextEditingController();
    final ageCtrl = TextEditingController(text: '40');
    final diagCtrl = TextEditingController();
    final roomCtrl = TextEditingController(text: 'Room C-101');
    final bedCtrl = TextEditingController(text: 'Bed 4');
    final reasonCtrl = TextEditingController(text: 'Initial Intake Consultation');
    String selectedGender = 'Male';
    String selectedBloodGroup = 'O+';
    String selectedDept = _hospital.departments.first;
    String? selectedInitialDocId;
    bool isAdmitted = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.personal_injury_rounded, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text('Register Patient in Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Patient Full Name *',
                    hintText: 'e.g. Ramesh Kumar',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone *',
                          hintText: '10-digit number',
                          prefixText: '+91 ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedBloodGroup,
                        decoration: const InputDecoration(labelText: 'Blood Group'),
                        items: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
                            .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedBloodGroup = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age (Years)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedGender,
                        decoration: const InputDecoration(labelText: 'Sex'),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedGender = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mrnCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medical Record Number (MRN)',
                    hintText: 'Optional (e.g. MRN-2026-004)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: diagCtrl,
                  decoration: const InputDecoration(labelText: 'Primary Diagnosis / Symptoms'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedDept,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedDept = val);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedInitialDocId,
                  decoration: const InputDecoration(
                    labelText: 'Assign Doctor (Initial Consultation)',
                    prefixIcon: Icon(Icons.assignment_ind_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned / Assign Later'),
                    ),
                    ...HospitalAdminRepository.getAllDoctors()
                        .where((d) => d.hospitalId == _hospitalId)
                        .map(
                          (doc) => DropdownMenuItem<String?>(
                            value: doc.id,
                            child: Text('${doc.name} (${doc.department})', overflow: TextOverflow.ellipsis),
                          ),
                        ),
                  ],
                  onChanged: (val) => setDlgState(() => selectedInitialDocId = val),
                ),
                if (selectedInitialDocId != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Consultation Reason / Notes'),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: roomCtrl,
                        decoration: const InputDecoration(labelText: 'Room No'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: bedCtrl,
                        decoration: const InputDecoration(labelText: 'Bed No'),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  title: const Text('Admit as Inpatient'),
                  value: isAdmitted,
                  onChanged: (val) => setDlgState(() => isAdmitted = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      if (name.isEmpty || phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill Patient Name and Phone')),
                        );
                        return;
                      }

                      setDlgState(() => isSubmitting = true);

                      final age = int.tryParse(ageCtrl.text.trim()) ?? 35;
                      final approxYear = DateTime.now().year - age;
                      final dob = '$approxYear-01-01';

                      final res = await ApiClient.createPatient(
                        fullName: name,
                        phone: phone,
                        dateOfBirth: dob,
                        sexAtBirth: selectedGender.toLowerCase(),
                        bloodGroup: selectedBloodGroup,
                        medicalRecordNumber: mrnCtrl.text.trim().isNotEmpty ? mrnCtrl.text.trim() : null,
                        initialDoctorUserId: selectedInitialDocId,
                        reason: selectedInitialDocId != null ? reasonCtrl.text.trim() : null,
                        profileData: {
                          'diagnosis': diagCtrl.text.trim().isNotEmpty ? diagCtrl.text.trim() : 'Observation',
                          'department': selectedDept,
                          'room_no': roomCtrl.text.trim(),
                          'bed_no': bedCtrl.text.trim(),
                          'is_admitted': isAdmitted,
                        },
                      );

                      if (!mounted) return;

                      if (res['success'] == true) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        final createdData = res['data'] ?? {};
                        final mrnAssigned = createdData['medical_record_number'] ?? '';
                        final hasAppt = createdData['appointment'] != null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF059669),
                            content: Text(hasAppt
                                ? 'Patient $name registered & initial consultation created! (MRN: $mrnAssigned)'
                                : 'Patient $name registered successfully in PostgreSQL! (MRN: $mrnAssigned)'),
                          ),
                        );
                        _loadLivePatients();
                        _loadLiveAppointments();
                      } else {
                        if (ctx.mounted) setDlgState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFDC2626),
                            content: Text(res['error'] ?? 'Failed to register patient in database.'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save to Database', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // REMOVE CONFIRMATIONS
  // ==========================================
  void _confirmRemoveDoctor(HospitalAdminStaffDoctor doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Doctor?'),
        content: Text(
          'Are you sure you want to permanently remove ${doc.name} (${doc.phone}) from ${_hospital.name}? All active shifts and database records will be revoked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiClient.deleteDoctor(doc.id);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF059669),
                      content: Text('Doctor ${doc.name} removed from database.'),
                    ),
                  );
                  _loadLiveDoctors();
                } else {
                  setState(() {
                    HospitalAdminRepository.removeDoctor(doc.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'] ?? 'Doctor removed.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove Doctor', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveWorker(HospitalAdminStaffWorker worker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Healthcare Worker?'),
        content: Text(
          'Are you sure you want to remove ${worker.name} (${worker.phone}) from ${_hospital.name}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                HospitalAdminRepository.removeWorker(worker.id);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Worker ${worker.name} removed from database.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove Worker', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRemovePatient(HospitalAdminPatient pat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Patient?'),
        content: Text(
          'Are you sure you want to remove patient ${pat.name} from the database?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiClient.deletePatient(pat.id);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Patient ${pat.name} removed from database.')),
                  );
                  _loadLivePatients();
                } else {
                  setState(() {
                    HospitalAdminRepository.removePatient(pat.id);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'] ?? 'Patient removed.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove Patient', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ASSIGN SHIFT DIALOG
  // ==========================================
  void _openAssignShiftDialog(
    List<HospitalAdminStaffDoctor> doctors,
    List<HospitalAdminStaffWorker> workers,
  ) {
    String selectedRole = 'Doctor';
    String selectedStaffId = doctors.isNotEmpty ? doctors.first.id : '';
    String selectedStaffName = doctors.isNotEmpty ? doctors.first.name : '';
    String selectedSlot = 'Morning (08:00 AM - 02:00 PM)';
    String selectedDept = _hospital.departments.first;
    final roomCtrl = TextEditingController(text: 'Chamber 104');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final staffList = selectedRole == 'Doctor'
              ? doctors.map((d) => {'id': d.id, 'name': d.name}).toList()
              : workers.map((w) => {'id': w.id, 'name': w.name}).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Color(0xFF047857)),
                SizedBox(width: 8),
                Text('Assign New Shift', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Staff Type'),
                    items: const [
                      DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
                      DropdownMenuItem(value: 'Worker', child: Text('Healthcare Worker')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() {
                          selectedRole = val;
                          if (val == 'Doctor' && doctors.isNotEmpty) {
                            selectedStaffId = doctors.first.id;
                            selectedStaffName = doctors.first.name;
                          } else if (val == 'Worker' && workers.isNotEmpty) {
                            selectedStaffId = workers.first.id;
                            selectedStaffName = workers.first.name;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStaffId.isNotEmpty ? selectedStaffId : null,
                    decoration: const InputDecoration(labelText: 'Staff Member'),
                    items: staffList.map((s) {
                      return DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? ''));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = staffList.firstWhere((element) => element['id'] == val);
                        setDlgState(() {
                          selectedStaffId = val;
                          selectedStaffName = found['name'] ?? '';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSlot,
                    decoration: const InputDecoration(labelText: 'Shift Slot'),
                    items: const [
                      DropdownMenuItem(value: 'Morning (08:00 AM - 02:00 PM)', child: Text('Morning (08:00 AM - 02:00 PM)')),
                      DropdownMenuItem(value: 'Evening (02:00 PM - 08:00 PM)', child: Text('Evening (02:00 PM - 08:00 PM)')),
                      DropdownMenuItem(value: 'Night (08:00 PM - 08:00 AM)', child: Text('Night (08:00 PM - 08:00 AM)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedSlot = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    decoration: const InputDecoration(labelText: 'Department'),
                    items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedDept = val);
                    },
                  ),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(labelText: 'Room / Ward / Chamber'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selectedStaffId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a staff member')),
                    );
                    return;
                  }

                  final newShift = HospitalShiftItem(
                    id: 'sh_${DateTime.now().millisecondsSinceEpoch}',
                    staffId: selectedStaffId,
                    staffName: selectedStaffName,
                    staffRole: selectedRole,
                    hospitalId: _hospitalId,
                    department: selectedDept,
                    roomOrWard: roomCtrl.text.trim().isNotEmpty ? roomCtrl.text.trim() : 'OPD Chamber',
                    date: DateTime.now(),
                    timeSlot: selectedSlot,
                    status: 'Active',
                  );

                  setState(() {
                    HospitalAdminRepository.addShift(newShift);
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF047857),
                      content: Text('Shift allocated to $selectedStaffName'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                child: const Text('Confirm Shift', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // ASSIGN PATIENT TO DOCTOR DIALOG
  // ==========================================
  void _showAssignDoctorDialog(HospitalAdminPatient pat) {
    final doctors = HospitalAdminRepository.getAllDoctors()
        .where((d) => d.hospitalId == _hospitalId)
        .toList();

    if (doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No doctors available in this facility to assign.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    String selectedDocId = pat.assignedDoctorUserId ?? doctors.first.id;
    if (!doctors.any((d) => d.id == selectedDocId)) {
      selectedDocId = doctors.first.id;
    }
    String selectedDocName = doctors.firstWhere((d) => d.id == selectedDocId).name;
    final reasonCtrl = TextEditingController(text: 'Primary Care Doctor Assignment');
    bool isAssigning = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Assign Doctor to Patient',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient: ${pat.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MRN: ${pat.medicalRecordNumber ?? 'N/A'} • Current: ${pat.assignedDoctor}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Doctor to Assign:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDocId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: doctors.map((doc) {
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(
                          '${doc.name} (${doc.department})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: isAssigning
                        ? null
                        : (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedDocId = val;
                                selectedDocName = doctors.firstWhere((d) => d.id == val).name;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    enabled: !isAssigning,
                    decoration: InputDecoration(
                      labelText: 'Assignment Reason / Consultation Note',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isAssigning ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isAssigning
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => isAssigning = true);
                      try {
                        final res = await ApiClient.assignPatientDoctor(
                          patientId: pat.id,
                          doctorUserId: selectedDocId,
                          reason: reasonCtrl.text.trim(),
                        );

                        if (res['success'] == true) {
                          if (mounted) {
                            setState(() {
                              pat.assignedDoctor = selectedDocName;
                              pat.assignedDoctorUserId = selectedDocId;
                            });
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          final actionMsg = res['message'] ?? '${pat.name} assigned to $selectedDocName & saved to database!';
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(actionMsg),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          if (mounted) {
                            _loadLivePatients();
                            _loadLiveAppointments();
                          }
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res['error'] ?? 'Failed to assign patient.'),
                              backgroundColor: AppColors.danger,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
                        );
                      } finally {
                        if (ctx.mounted) setModalState(() => isAssigning = false);
                      }
                    },
                icon: isAssigning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                label: Text(
                  isAssigning ? 'ASSIGNING...' : 'CONFIRM ASSIGNMENT',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
