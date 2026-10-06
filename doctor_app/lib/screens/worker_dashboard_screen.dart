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
  String _activeFilter = 'NewRequests'; // 'NewRequests', 'ActiveCases', 'Today', 'Referrals', 'Recent', 'All'
  String _scopeFilter = 'MyCases'; // 'MyCases' (individual worker) vs 'AllCases' (entire unit)

  List<AppointmentItem> _liveAppointments = [];
  List<AppointmentItem> _liveAshaRequests = [];
  bool _isLoadingAppointments = false;
  bool _isLoadingPatients = false;
  bool _isLoadingAsha = false;

  bool _isMyCase(AppointmentItem item) {
    final myId = widget.userProfile?.userId;
    final myName = widget.userProfile?.name.trim().toLowerCase() ?? '';

    final notes = item.notes;
    if (notes != null) {
      final acceptedById = notes['accepted_by_user_id']?.toString();
      if (myId != null && acceptedById != null && acceptedById == myId) {
        return true;
      }
      final createdById = notes['created_by_user_id']?.toString();
      if (myId != null && createdById != null && createdById == myId) {
        return true;
      }
      final referredById = notes['referred_by_worker_id']?.toString() ?? notes['forwarded_by_user_id']?.toString();
      if (myId != null && referredById != null && referredById == myId) {
        return true;
      }
      final managedById = notes['managed_by_user_id']?.toString();
      if (myId != null && managedById != null && managedById == myId) {
        return true;
      }

      final acceptedByName = (notes['accepted_by_name']?.toString() ?? '').trim().toLowerCase();
      if (myName.isNotEmpty && acceptedByName.isNotEmpty) {
        if (acceptedByName == myName || acceptedByName.contains(myName) || myName.contains(acceptedByName)) {
          return true;
        }
      }

      final forwardedByName = (notes['forwarded_by']?.toString() ?? notes['referred_by_worker_name']?.toString() ?? '').trim().toLowerCase();
      if (myName.isNotEmpty && forwardedByName.isNotEmpty) {
        if (forwardedByName == myName || forwardedByName.contains(myName) || myName.contains(forwardedByName)) {
          return true;
        }
      }
    }

    if (myId != null && item.providerUserId != null && item.providerUserId == myId) {
      return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _hospitalId = widget.userProfile?.hospitalId ?? 'hosp_1';
    _hospital = HospitalAdminRepository.getHospitalDetails(_hospitalId);
    _loadLivePatients();
    _loadLiveDoctors();
    _loadLiveAppointments();
    _loadLiveAshaRequests();
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
            medicalRecordNumber: row['medical_record_number']?.toString() ?? '',
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

  Future<void> _loadLiveAshaRequests() async {
    setState(() => _isLoadingAsha = true);
    try {
      final list = await ApiClient.getAshaRequests();
      if (!mounted) return;
      setState(() {
        _liveAshaRequests = list;
        _isLoadingAsha = false;
      });
    } catch (e) {
      debugPrint('Error loading asha requests in worker screen: $e');
      if (mounted) setState(() => _isLoadingAsha = false);
    }
  }

  Future<void> _acceptAshaRequest(AppointmentItem req) async {
    try {
      final updatedNotes = req.notes != null ? Map<String, dynamic>.from(req.notes!) : <String, dynamic>{};
      final workerId = widget.userProfile?.userId;
      final workerName = widget.userProfile?.name ?? 'Healthcare Worker';

      updatedNotes['accepted_by_user_id'] = workerId;
      updatedNotes['accepted_by_name'] = workerName;
      updatedNotes['accepted_at'] = DateTime.now().toIso8601String();

      final res = await ApiClient.updateAppointment(
        appointmentId: req.id,
        status: 'confirmed',
        notes: updatedNotes,
      );
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request for ${req.patientName} accepted! Case is now active in My Cases.'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
        setState(() {
          _activeFilter = 'ActiveCases';
        });
        await Future.wait([
          _loadLiveAshaRequests(),
          _loadLiveAppointments(),
          _loadLivePatients(),
        ]);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to accept request.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _openPatientAssessment(AppointmentItem req) {
    final existing = HospitalAdminRepository.getPatients(_hospitalId)
        .where((p) => p.id == req.patientId)
        .toList();

    final pat = existing.isNotEmpty
        ? existing.first
        : HospitalAdminPatient(
            id: req.patientId ?? 'pat_${DateTime.now().millisecondsSinceEpoch}',
            name: req.patientName.isNotEmpty ? req.patientName : 'Field Patient',
            phone: (req.patientPhone != null && req.patientPhone!.isNotEmpty) ? req.patientPhone! : 'Field Patient',
            password: '••••',
            age: req.age > 0 ? req.age : 30,
            gender: req.gender.isNotEmpty ? req.gender : 'Other',
            diagnosis: req.diagnosis.isNotEmpty ? req.diagnosis : 'Primary Health Assessment',
            department: 'Field Medicine',
            hospitalId: _hospitalId,
            hospitalName: _hospital.name,
            roomNo: 'Field Visit',
            bedNo: 'N/A',
            isAdmitted: false,
            assignedDoctor: 'ASHA Worker Unit',
            admissionDate: DateTime.now().toIso8601String().split('T').first,
            medicalRecordNumber: req.medicalRecordNumber ?? '',
            bloodGroup: req.bloodGroup ?? 'N/A',
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          patient: pat,
          userProfile: widget.userProfile,
          initialAshaRequest: req,
          openAssessmentImmediately: true,
        ),
      ),
    ).then((_) {
      _loadLiveAshaRequests();
      _loadLiveAppointments();
      _loadLivePatients();
    });
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

    final allNewRequests = _liveAshaRequests.where((r) => r.status.toLowerCase() == 'queued').toList();
    final allActiveCases = _liveAshaRequests.where((r) => r.status.toLowerCase() == 'confirmed' || r.status.toLowerCase() == 'in_progress').toList();
    final allTodayAppts = _liveAppointments.where((a) {
      final t = a.timing.toLowerCase();
      return t.contains('today') || t.contains('now');
    }).toList();
    final allReferrals = _liveAppointments.where((a) => (a.notes != null && a.notes!['referral_type'] == 'asha_referral') || a.diagnosis.toLowerCase().contains('referral') || a.diagnosis.toLowerCase().contains('referred')).toList();
    final allRecentCases = _liveAshaRequests.where((r) => r.status.toLowerCase() == 'completed').toList();

    // Individual worker filtering
    final myActiveCases = allActiveCases.where(_isMyCase).toList();
    final myTodayAppts = allTodayAppts.where(_isMyCase).toList();
    final myReferrals = allReferrals.where(_isMyCase).toList();
    final myRecentCases = allRecentCases.where(_isMyCase).toList();

    final myTotalCount = myActiveCases.length + myReferrals.length + myRecentCases.length;
    final unitTotalCount = allActiveCases.length + allReferrals.length + allRecentCases.length;

    final isMyCases = _scopeFilter == 'MyCases';
    final activeCases = isMyCases ? myActiveCases : allActiveCases;
    final todayAppts = isMyCases ? myTodayAppts : allTodayAppts;
    final referrals = isMyCases ? myReferrals : allReferrals;
    final recentCases = isMyCases ? myRecentCases : allRecentCases;
    final newRequests = allNewRequests; // Collective inbox for all field workers

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
            const SizedBox(height: 8),

            // Scope Selector: "My Cases" vs "All Unit Cases"
            _buildScopeSelector(
              myTotalCount: myTotalCount,
              unitTotalCount: unitTotalCount,
            ),

            const SizedBox(height: 8),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: isMyCases
                      ? 'Search my patients by name, symptoms, phone...'
                      : 'Search all unit patients by name, symptoms, phone...',
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

            // Filter Chips Bar: New Requests | Active Cases | Today | Referrals | Recent | All
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'New Requests (${newRequests.length})',
                      filterKey: 'NewRequests',
                      isHighlight: newRequests.isNotEmpty,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isMyCases ? 'My Active (${activeCases.length})' : 'Active Cases (${activeCases.length})',
                      filterKey: 'ActiveCases',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isMyCases ? 'My Today (${todayAppts.length})' : 'Today (${todayAppts.length})',
                      filterKey: 'Today',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isMyCases ? 'My Referrals (${referrals.length})' : 'Referrals (${referrals.length})',
                      filterKey: 'Referrals',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: isMyCases ? 'My Completed (${recentCases.length})' : 'Recent (${recentCases.length})',
                      filterKey: 'Recent',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'All Patients (${patients.length})',
                      filterKey: 'All',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Tab Content
            Expanded(
              child: _buildSelectedTabContent(
                newRequests: newRequests,
                activeCases: activeCases,
                todayAppts: todayAppts,
                referrals: referrals,
                recentCases: recentCases,
                filteredPatients: filteredPatients,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeSelector({required int myTotalCount, required int unitTotalCount}) {
    final isMyCases = _scopeFilter == 'MyCases';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _scopeFilter = 'MyCases'),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isMyCases ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isMyCases
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_pin_rounded,
                        size: 16,
                        color: isMyCases ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'My Cases ($myTotalCount)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMyCases ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _scopeFilter = 'AllCases'),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: !isMyCases ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: !isMyCases
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 16,
                        color: !isMyCases ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'All Unit Cases ($unitTotalCount)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: !isMyCases ? const Color(0xFF0F766E) : const Color(0xFF64748B),
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

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    bool isHighlight = false,
  }) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F766E)
              : (isHighlight ? const Color(0xFFFEF3C7) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F766E)
                : (isHighlight ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
            width: isHighlight ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isHighlight ? const Color(0xFFB45309) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent({
    required List<AppointmentItem> newRequests,
    required List<AppointmentItem> activeCases,
    required List<AppointmentItem> todayAppts,
    required List<AppointmentItem> referrals,
    required List<AppointmentItem> recentCases,
    required List<HospitalAdminPatient> filteredPatients,
  }) {
    final isMyCases = _scopeFilter == 'MyCases';
    switch (_activeFilter) {
      case 'NewRequests':
        return _buildAshaRequestsList(newRequests, isNew: true, emptyMessage: 'No incoming ASHA visit requests in unit inbox.');
      case 'ActiveCases':
        return _buildAshaRequestsList(
          activeCases,
          isNew: false,
          emptyMessage: isMyCases
              ? 'You have no active cases assigned to you.\nCheck "New Requests" to accept cases or switch to "All Unit Cases".'
              : 'No active assessment cases in progress across the unit.',
        );
      case 'Today':
        return _buildAppointmentsList(
          todayAppts,
          emptyMessage: isMyCases
              ? 'No visits or consultations scheduled for you today.'
              : 'No visits or consultations scheduled across the unit today.',
        );
      case 'Referrals':
        return _buildAppointmentsList(
          referrals,
          emptyMessage: isMyCases
              ? 'No patients referred to doctors by you yet.'
              : 'No patients referred to doctors across the unit yet.',
        );
      case 'Recent':
        return _buildAshaRequestsList(
          recentCases,
          isNew: false,
          emptyMessage: isMyCases
              ? 'You have no completed field cases yet.'
              : 'No completed field cases yet across the unit.',
        );
      case 'All':
      default:
        return _buildPatientsRosterTab(filteredPatients);
    }
  }

  Widget _buildAshaRequestsList(List<AppointmentItem> list, {required bool isNew, required String emptyMessage}) {
    if (_isLoadingAsha) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadLiveAshaRequests(), _loadLiveAppointments(), _loadLivePatients()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNew ? Icons.inbox_rounded : Icons.check_circle_outline_rounded,
                      size: 48,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pull down to refresh live state from Azure PostgreSQL.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
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
        await Future.wait([_loadLiveAshaRequests(), _loadLiveAppointments(), _loadLivePatients()]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final req = list[index];
          return _buildAshaRequestCard(req, isNew: isNew);
        },
      ),
    );
  }

  Widget _buildAshaRequestCard(AppointmentItem req, {required bool isNew}) {
    final urgency = req.notes?['urgency']?.toString().toLowerCase() ?? 'routine';
    Color urgencyBg = const Color(0xFFECFDF5);
    Color urgencyColor = const Color(0xFF059669);
    if (urgency == 'emergency') {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyColor = const Color(0xFFDC2626);
    } else if (urgency == 'priority') {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyColor = const Color(0xFFD97706);
    }

    final isQueued = req.status.toLowerCase() == 'queued';
    final isConfirmed = req.status.toLowerCase() == 'confirmed';
    final isInProgress = req.status.toLowerCase() == 'in_progress';
    final isCompleted = req.status.toLowerCase() == 'completed';
    final isAssignedToMe = _isMyCase(req);
    final acceptedByName = req.notes?['accepted_by_name']?.toString() ??
        req.notes?['managed_by_name']?.toString() ??
        req.notes?['referred_by_worker_name']?.toString() ??
        req.notes?['forwarded_by']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isQueued
              ? const Color(0xFFF59E0B)
              : (isAssignedToMe ? const Color(0xFF0F766E).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
          width: (isQueued || isAssignedToMe) ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Patient Name & Urgency Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isAssignedToMe ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
                        child: Icon(
                          isAssignedToMe ? Icons.verified_user_rounded : Icons.person,
                          color: isAssignedToMe ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.patientName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Phone: ${(req.patientPhone != null && req.patientPhone!.isNotEmpty) ? req.patientPhone! : "Not listed"}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: urgencyBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    urgency.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: urgencyColor),
                  ),
                ),
              ],
            ),

            // Worker Assignment Badge
            if (!isQueued) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAssignedToMe ? const Color(0xFFCCFBF1) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isAssignedToMe
                            ? const Color(0xFF14B8A6).withValues(alpha: 0.4)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAssignedToMe ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                          size: 13,
                          color: isAssignedToMe ? const Color(0xFF0F766E) : const Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAssignedToMe
                              ? 'Your Active Case'
                              : (acceptedByName != null && acceptedByName.isNotEmpty
                                  ? 'Assigned: $acceptedByName'
                                  : 'Assigned to Unit Worker'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAssignedToMe ? const Color(0xFF0F766E) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Reason / Symptoms box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reported Reason / Symptoms:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text(
                    req.diagnosis.isNotEmpty ? req.diagnosis : 'Primary care evaluation requested',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                  ),
                  if (req.timing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Requested Timing: ${req.timing}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                if (isQueued) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptAshaRequest(req),
                      icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      label: const Text('Accept Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _openPatientAssessment(req),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Text('View & Assess', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ] else if (isConfirmed || isInProgress) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openPatientAssessment(req),
                      icon: const Icon(Icons.medical_services_rounded, size: 16, color: Colors.white),
                      label: Text(
                        isAssignedToMe
                            ? 'Assess Patient (Vitals & Clinical)'
                            : 'Assess / Assist Case (${acceptedByName != null && acceptedByName.isNotEmpty ? acceptedByName : "Assigned Worker"})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                  ),
                ] else if (isCompleted) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPatientAssessment(req),
                      icon: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF059669)),
                      label: const Text('Completed Case History', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF059669)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(List<AppointmentItem> list, {required String emptyMessage}) {
    if (_isLoadingAppointments) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadLiveAshaRequests(), _loadLiveAppointments(), _loadLivePatients()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_note_rounded, size: 48, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    emptyMessage,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    textAlign: TextAlign.center,
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
        await Future.wait([_loadLiveAshaRequests(), _loadLiveAppointments(), _loadLivePatients()]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final appt = list[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AppointmentDetailScreen(appointment: appt)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          appt.appointmentNo.isNotEmpty ? appt.appointmentNo : appt.id,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            appt.status.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      appt.patientName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      'Timing: ${appt.timing} • Doctor: ${appt.doctorName ?? "Assigned Doctor"}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Reason: ${appt.diagnosis}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                      ),
                    ),
                    if (appt.notes?['forwarded_by'] != null ||
                        appt.notes?['referred_by_worker_name'] != null ||
                        appt.notes?['accepted_by_name'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.forward_to_inbox_rounded, size: 13, color: Color(0xFF0F766E)),
                          const SizedBox(width: 4),
                          Text(
                            'Referred by: ${appt.notes?['forwarded_by'] ?? appt.notes?['referred_by_worker_name'] ?? appt.notes?['accepted_by_name']}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPatientsRosterTab(List<HospitalAdminPatient> filteredPatients) {
    if (_isLoadingPatients) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (filteredPatients.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 54, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No patients found in your field roster',
              style: TextStyle(fontSize: 15, color: Color(0xFF64748B)),
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
          _loadLiveAshaRequests(),
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
    final medCtrl = TextEditingController(text: '');
    final dosageCtrl = TextEditingController(text: '1 Tablet');
    final durationCtrl = TextEditingController(text: '5 Days');
    final notesCtrl = TextEditingController(text: 'Adequate hydration, warm water rest');

    bool morningOn = true;
    bool afternoonOn = false;
    bool nightOn = false;

    const commonMedicines = [
      'Paracetamol',
      'Ibuprofen',
      'Amoxicillin',
      'Azithromycin',
      'Cetirizine',
      'Pantoprazole',
      'Omeprazole',
      'Metformin',
      'Amlodipine',
      'ORS',
      'Ondansetron',
      'Diclofenac',
      'Levocetirizine',
      'Albendazole',
      'Atorvastatin',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final frequency =
              '${morningOn ? "1" : "0"}-${afternoonOn ? "1" : "0"}-${nightOn ? "1" : "0"}';
          final hasValidTiming = morningOn || afternoonOn || nightOn;

          return AlertDialog(
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

                  // Medicine Selector
                  const Text('Medicine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: medCtrl,
                    decoration: InputDecoration(
                      hintText: 'Select or type medicine... ▼',
                      prefixIcon: const Icon(Icons.medication_outlined, size: 20, color: Color(0xFF0F766E)),
                      suffixIcon: PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 30, color: Color(0xFF0F766E)),
                        tooltip: 'Choose medicine',
                        onSelected: (val) {
                          medCtrl.text = val;
                          setDlgState(() {});
                        },
                        itemBuilder: (ctx) => commonMedicines
                            .map((m) => PopupMenuItem(value: m, child: Text(m)))
                            .toList(),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: commonMedicines.map((m) {
                        final isSel = medCtrl.text.trim().toLowerCase() == m.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(m, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                            backgroundColor: isSel ? const Color(0xFF0F766E) : const Color(0xFFF1F5F9),
                            onPressed: () {
                              medCtrl.text = m;
                              setDlgState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: dosageCtrl,
                    decoration: const InputDecoration(labelText: 'Dosage (e.g. 1 Tablet)'),
                  ),
                  const SizedBox(height: 12),

                  // Timing Switches
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !hasValidTiming ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Medicine Timing', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Text(
                              'Frequency: $frequency',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasValidTiming ? const Color(0xFF0F766E) : const Color(0xFFE11D48),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Morning'),
                            Switch.adaptive(
                              value: morningOn,
                              onChanged: (val) => setDlgState(() => morningOn = val),
                              activeTrackColor: const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Afternoon'),
                            Switch.adaptive(
                              value: afternoonOn,
                              onChanged: (val) => setDlgState(() => afternoonOn = val),
                              activeTrackColor: const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Night'),
                            Switch.adaptive(
                              value: nightOn,
                              onChanged: (val) => setDlgState(() => nightOn = val),
                              activeTrackColor: const Color(0xFF0F766E),
                            ),
                          ],
                        ),
                        if (!hasValidTiming)
                          const Text('Select at least one time.', style: TextStyle(fontSize: 11, color: Color(0xFFE11D48))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: durationCtrl,
                    decoration: const InputDecoration(labelText: 'Duration'),
                  ),
                  const SizedBox(height: 12),
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
                  if (medCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select or type a medicine name')),
                    );
                    return;
                  }
                  if (!hasValidTiming) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select at least one time')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF0F766E),
                      content: Text('Prescription issued for ${pat.name} ($frequency)!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                child: const Text('Create Prescription', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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

                        // Also persist to live backend database
                        ApiClient.createAppointment(
                          patientId: pat.id,
                          doctorUserId: selectedDoctor!.id,
                          appointmentType: 'clinic',
                          status: 'confirmed',
                          reason: reasonCtrl.text.trim().isNotEmpty
                              ? reasonCtrl.text.trim()
                              : 'Worker Clinical Forwarding ($selectedUrgency)',
                          notes: {
                            'referral_type': 'asha_referral',
                            'urgency': selectedUrgency,
                            'forwarded_by': widget.userProfile?.name ?? 'Worker Sunita Devi',
                            'forwarded_by_user_id': widget.userProfile?.userId,
                            'accepted_by_user_id': widget.userProfile?.userId,
                            'accepted_by_name': widget.userProfile?.name ?? 'Worker Sunita Devi',
                            'specialty': selectedSpecialty,
                            'vitals': pat.vitals,
                          },
                        ).then((_) {
                          if (mounted) _loadLiveAppointments();
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
                                        '${selectedDoctor!.designation} ($selectedSpecialty)',
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
