import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/user_profile.dart';
import '../models/hospital_admin_repository.dart';
import '../models/room_machine_models.dart';
import 'login_screen.dart';

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

  // Staff sub-tab: 0 = Doctors, 1 = Workers, 2 = Patients
  int _staffSubTabIndex = 0;
  String _searchQuery = '';
  final Set<String> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hospitalId = widget.userProfile?.hospitalId ?? 'hosp_1';
    _refreshHospitalData();
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
                      onPressed: () {
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
        // Sub-Tab Switcher: Doctors | Workers | Patients
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildSubTabChip(
                  index: 0,
                  label: 'Doctors (${doctors.length})',
                  icon: Icons.medical_services_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubTabChip(
                  index: 1,
                  label: 'Workers (${workers.length})',
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSubTabChip(
                  index: 2,
                  label: 'Patients (${patients.length})',
                  icon: Icons.personal_injury_outlined,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search Bar & Add Button
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
                            : 'Search patients by name or diagnosis...',
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
                  : _buildPatientsList(patients),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
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
      return _buildEmptyState('No doctors found in ${_hospital.name}');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final doc = filtered[index];
        final isPassVisible = _visiblePasswords.contains(doc.id);

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
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Remove Doctor from Database',
                      onPressed: () => _confirmRemoveDoctor(doc),
                    ),
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFF1F5F9)),

                // Details Grid: Chamber, Shift, Duty Toggle, and PASSWORD
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
                          _buildDetailRow(Icons.phone_outlined, 'Phone: ${doc.phone}'),
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
                              doc.isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: doc.isOnDuty ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              ),
                            ),
                            Switch(
                              value: doc.isOnDuty,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() {
                                  HospitalAdminRepository.toggleStaffDuty(doc.id, true);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // PASSWORD BOX FOR ADMIN (Full Credentials Control)
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
                        'Password: ${isPassVisible ? doc.password : '••••••••'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _togglePasswordVisibility(doc.id),
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

  // --- WORKERS LIST ---
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
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.phone.contains(_searchQuery) ||
          p.diagnosis.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState('No patients registered in ${_hospital.name}');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final pat = filtered[index];
        final isPassVisible = _visiblePasswords.contains(pat.id);

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
                          Text(
                            '${pat.age} Yrs • ${pat.gender} • ${pat.department}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      tooltip: 'Remove Patient from Database',
                      onPressed: () => _confirmRemovePatient(pat),
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
                          _buildDetailRow(Icons.hotel_outlined, 'Bed: ${pat.roomNo} (${pat.bedNo})'),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.person_pin_circle_outlined, 'Doctor: ${pat.assignedDoctor}'),
                          const SizedBox(height: 4),
                          _buildDetailRow(Icons.phone_outlined, 'Phone: ${pat.phone}'),
                        ],
                      ),
                    ),
                    if (pat.forwardedToDoctor != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FORWARDED TO',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                            ),
                            Text(
                              pat.forwardedToDoctor!,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF312E81)),
                            ),
                            Text(
                              pat.urgency ?? 'Routine',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Patient Portal Password / PIN
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
                        'Portal Password / PIN: ${isPassVisible ? pat.password : '••••'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _togglePasswordVisibility(pat.id),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${room.roomNumber}: ${room.roomName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(width: 8),
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
  // ADD DOCTOR DIALOG
  // ==========================================
  void _openAddDoctorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final qualCtrl = TextEditingController();
    final desigCtrl = TextEditingController(text: 'Consultant Specialist');
    final expCtrl = TextEditingController(text: '8');
    final chamberCtrl = TextEditingController(text: 'Chamber 108');
    final shiftCtrl = TextEditingController(text: '08:00 AM - 02:00 PM');
    String selectedDept = _hospital.departments.first;

    showDialog(
      context: context,
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
                  decoration: const InputDecoration(labelText: 'Doctor Full Name', hintText: 'e.g. Dr. Ramesh Gupta'),
                ),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (Login Username)', hintText: '10 digits'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Password (Credentials)', hintText: 'Set login password'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedDept = val);
                  },
                ),
                TextField(
                  controller: qualCtrl,
                  decoration: const InputDecoration(labelText: 'Qualification', hintText: 'MBBS, MD, DM'),
                ),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
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
                TextField(
                  controller: shiftCtrl,
                  decoration: const InputDecoration(labelText: 'Shift Timing'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
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

                final newDoc = HospitalAdminStaffDoctor(
                  id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
                  name: name.startsWith('Dr.') ? name : 'Dr. $name',
                  phone: phone,
                  password: pass,
                  department: selectedDept,
                  qualification: qualCtrl.text.trim().isNotEmpty ? qualCtrl.text.trim() : 'MBBS, MD',
                  designation: desigCtrl.text.trim(),
                  experienceYears: int.tryParse(expCtrl.text.trim()) ?? 5,
                  chamberNo: chamberCtrl.text.trim(),
                  hospitalId: _hospitalId,
                  hospitalName: _hospital.name,
                  isOnDuty: true,
                  shiftTiming: shiftCtrl.text.trim(),
                  email: '${phone}@${_hospital.name.toLowerCase().replaceAll(' ', '')}.org',
                );

                setState(() {
                  HospitalAdminRepository.addDoctor(newDoc);
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('Doctor ${newDoc.name} registered with credentials!'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Doctor', style: TextStyle(color: Colors.white)),
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
    final passCtrl = TextEditingController(text: '1234');
    final ageCtrl = TextEditingController(text: '40');
    final diagCtrl = TextEditingController();
    final roomCtrl = TextEditingController(text: 'Room C-101');
    final bedCtrl = TextEditingController(text: 'Bed 4');
    String selectedGender = 'Male';
    String selectedDept = _hospital.departments.first;
    bool isAdmitted = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.personal_injury_rounded, color: Color(0xFFE11D48)),
              SizedBox(width: 8),
              Text('Add Patient Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Patient Full Name'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: passCtrl,
                        decoration: const InputDecoration(labelText: 'Portal PIN/Password'),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGender,
                        decoration: const InputDecoration(labelText: 'Gender'),
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
                TextField(
                  controller: diagCtrl,
                  decoration: const InputDecoration(labelText: 'Primary Diagnosis / Symptoms'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: const InputDecoration(labelText: 'Department'),
                  items: _hospital.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedDept = val);
                  },
                ),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final pass = passCtrl.text.trim();

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill Patient Name and Phone')),
                  );
                  return;
                }

                final newPatient = HospitalAdminPatient(
                  id: 'pat_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  phone: phone,
                  password: pass.isNotEmpty ? pass : '1234',
                  age: int.tryParse(ageCtrl.text.trim()) ?? 35,
                  gender: selectedGender,
                  diagnosis: diagCtrl.text.trim().isNotEmpty ? diagCtrl.text.trim() : 'Observation',
                  department: selectedDept,
                  hospitalId: _hospitalId,
                  hospitalName: _hospital.name,
                  roomNo: roomCtrl.text.trim(),
                  bedNo: bedCtrl.text.trim(),
                  isAdmitted: isAdmitted,
                  assignedDoctor: 'Dr. Rajesh V. Sharma',
                  admissionDate: 'Today, Just Now',
                );

                setState(() {
                  HospitalAdminRepository.addPatient(newPatient);
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFE11D48),
                    content: Text('Patient ${newPatient.name} added with PIN: ${newPatient.password}'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
              child: const Text('Save Patient', style: TextStyle(color: Colors.white)),
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
          'Are you sure you want to permanently remove ${doc.name} (${doc.phone}) from ${_hospital.name}? All active shifts and login credentials will be revoked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                HospitalAdminRepository.removeDoctor(doc.id);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Doctor ${doc.name} removed from database.')),
              );
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
        title: const Text('Remove Worker?'),
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
          'Are you sure you want to discharge and remove patient ${pat.name} from the database?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                HospitalAdminRepository.removePatient(pat.id);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Patient ${pat.name} removed from database.')),
              );
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
                    value: selectedRole,
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
                    value: selectedStaffId.isNotEmpty ? selectedStaffId : null,
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
                    value: selectedSlot,
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
                    value: selectedDept,
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
}
