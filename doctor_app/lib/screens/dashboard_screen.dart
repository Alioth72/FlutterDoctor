import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_assets.dart';
import '../models/appointment_model.dart';
import '../models/user_profile.dart';
import 'appointment_detail_screen.dart';
import 'qr_workflow_screen.dart';
import 'pandemic_alert_screen.dart';
import 'doctor_duty_schedule_screen.dart';
import 'pharmacy_stock_screen.dart';
import 'machine_records_screen.dart';
import 'colleague_consult_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

enum DoctorAvailabilityMode {
  notAvailable, // 1st: Not available for hospital -> Grey
  available,    // 2nd: Available in hospital -> Purple
  emergency,    // 3rd: Emergency -> Red + Complete notifications, calls & alerts blocked
}

class DashboardScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const DashboardScreen({super.key, this.userProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Doctor Hospital Availability Mode (Default: Available / Purple)
  DoctorAvailabilityMode _availabilityMode = DoctorAvailabilityMode.available;

  Color get _currentPrimaryColor {
    switch (_availabilityMode) {
      case DoctorAvailabilityMode.notAvailable:
        return const Color(0xFF4B5563); // Grey
      case DoctorAvailabilityMode.available:
        return AppColors.primary; // Purple (0xFF7C3AED)
      case DoctorAvailabilityMode.emergency:
        return const Color(0xFFDC2626); // Emergency Red
    }
  }

  Color get _currentPrimaryDark {
    switch (_availabilityMode) {
      case DoctorAvailabilityMode.notAvailable:
        return const Color(0xFF1F2937); // Dark Grey
      case DoctorAvailabilityMode.available:
        return AppColors.primaryDark; // Deep Purple (0xFF4C1D95)
      case DoctorAvailabilityMode.emergency:
        return const Color(0xFF991B1B); // Deep Red
    }
  }

  Color get _currentPrimaryLight {
    switch (_availabilityMode) {
      case DoctorAvailabilityMode.notAvailable:
        return const Color(0xFFE5E7EB); // Light Grey
      case DoctorAvailabilityMode.available:
        return AppColors.primaryLight; // Light Purple
      case DoctorAvailabilityMode.emergency:
        return const Color(0xFFFEE2E2); // Light Red
    }
  }

  Color get _currentBackgroundColor {
    switch (_availabilityMode) {
      case DoctorAvailabilityMode.notAvailable:
        return const Color(0xFFF3F4F6); // Grey background
      case DoctorAvailabilityMode.available:
        return AppColors.background; // Soft purple background
      case DoctorAvailabilityMode.emergency:
        return const Color(0xFFFEF2F2); // Red tinted emergency background
    }
  }

  LinearGradient get _currentPrimaryGradient {
    return LinearGradient(
      colors: [_currentPrimaryDark, _currentPrimaryColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  final Set<String> _dismissedAppointmentIds = {};

  final List<AppointmentItem> _appointments = [
    AppointmentItem(
      id: '1',
      appointmentNo: 'APT-101',
      patientName: 'Rajesh Sharma',
      age: 45,
      gender: 'Male',
      timing: '10:30 AM - Today',
      paymentStatus: 'Paid Online (₹500)',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['Type 2 Diabetes', 'Hypertension (2 yrs)', 'Appendectomy 2021'],
      heightCm: 172.0,
      weightKg: 74.0,
      familyHistory: 'Father: Type 2 Diabetes, Mother: Hypertension',
      diagnosis: 'Acute Rhinitis & Mild Fever',
      medicines: [
        MedicineItem(
          name: 'Paracetamol 650mg',
          dosage: '1-0-1 after food',
          duration: '3 Days',
          closestClinic: 'Ashwini Central Pharmacy (In-Stock)',
        ),
        MedicineItem(
          name: 'Cetirizine 10mg',
          dosage: '0-0-1 before sleep',
          duration: '5 Days',
          closestClinic: 'Ashwini OPD Dispensary (In-Stock)',
        ),
      ],
      isAdmitted: true,
      roomNo: 'IPD Ward 304 - Bed 12',
      dietarySuggestions: 'Diabetic Low-Sodium Diet (1800 kcal), Soft foods & Warm fluids. Avoid refined sugars.',
      inpatientSchedules: [
        InpatientProcedureItem(
          title: 'Inj. Insulin Human 10 IU (Subcutaneous)',
          timing: '08:00 AM & 08:00 PM (Before Meals)',
          instructions: 'Administer subcutaneously in abdomen. Monitor blood glucose 15 mins prior.',
          category: 'Injection',
        ),
        InpatientProcedureItem(
          title: 'Inj. Ceftriaxone 1g IV Push',
          timing: '10:00 AM & 10:00 PM',
          instructions: 'Inject slowly via IV line over 3-5 mins.',
          category: 'IV Drip',
        ),
        InpatientProcedureItem(
          title: 'Inj. Pantoprazole 40mg IV',
          timing: '07:00 AM (Empty Stomach)',
          instructions: 'Dilute in 10ml Normal Saline IV push.',
          category: 'Injection',
        ),
      ],
    ),
    AppointmentItem(
      id: '2',
      appointmentNo: 'APT-102',
      patientName: 'Priya Verma',
      age: 32,
      gender: 'Female',
      timing: '11:15 AM - Today',
      paymentStatus: 'Payment Pending (Cash)',
      isPaid: false,
      mode: AppointmentMode.teleconsultation,
      patientHistory: ['Asthma (Mild)', 'Migraine'],
      heightCm: 162.5,
      weightKg: 58.0,
      familyHistory: 'Mother: Asthma',
      diagnosis: 'Seasonal Allergy',
      medicines: [
        MedicineItem(
          name: 'Levocetirizine 5mg',
          dosage: '0-0-1',
          duration: '5 Days',
          closestClinic: 'City Metro Clinic Pharmacy',
        ),
      ],
      isAdmitted: false,
    ),
    AppointmentItem(
      id: '3',
      appointmentNo: 'APT-103',
      patientName: 'Amitabh Patel',
      age: 58,
      gender: 'Male',
      timing: '12:00 PM - Today',
      paymentStatus: 'Paid Online (₹650)',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['Post-Op Knee Replacement (6 mos)', 'High Cholesterol'],
      heightCm: 178.0,
      weightKg: 82.0,
      familyHistory: 'Father: Ischemic Heart Disease',
      diagnosis: 'Post-Op Knee Checkup',
      medicines: [
        MedicineItem(
          name: 'Glucosamine 500mg',
          dosage: '1-0-1',
          duration: '30 Days',
          closestClinic: 'Ashwini Central Pharmacy',
        ),
      ],
      isAdmitted: true,
      roomNo: 'Special Ward 108 - Bed 02',
      dietarySuggestions: 'High Protein & Collagen Rich Diet. Soft solids with adequate hydration.',
      inpatientSchedules: [
        InpatientProcedureItem(
          title: 'Inj. Tramadol 50mg IV Slow Drip',
          timing: '02:00 PM & 10:00 PM',
          instructions: 'Dilute in 100ml 0.9% NS drip over 30 mins.',
          category: 'IV Drip',
        ),
        InpatientProcedureItem(
          title: 'Inj. Enoxaparin 40mg (Subcutaneous)',
          timing: '09:00 PM (Once Daily)',
          instructions: 'Deep subcutaneous injection in abdominal wall for DVT prophylaxis.',
          category: 'Injection',
        ),
      ],
    ),
  ];

  final List<AppointmentItem> _transferredAppointments = [];
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _loadLiveAppointments();
  }

  Future<void> _loadLiveAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      var liveList = await ApiClient.getAppointments(
        providerUserId: widget.userProfile?.userId,
      );
      if (liveList == null || liveList.isEmpty) {
        liveList = await ApiClient.getAppointments();
      }
      if (liveList != null && liveList.isNotEmpty && mounted) {
        setState(() {
          _appointments.clear();
          _appointments.addAll(
            liveList!.where((a) => !_dismissedAppointmentIds.contains(a.id)),
          );
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingAppointments = false);
  }

  void _deleteAppointment(int index) {
    final appt = _appointments[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Appointment'),
        content: Text('Are you sure you want to delete appointment for ${appt.patientName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _appointments.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Appointment ${appt.appointmentNo} deleted'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _transferAppointment(int index) {
    final appt = _appointments[index];
    setState(() {
      _transferredAppointments.add(appt);
      _appointments.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment ${appt.appointmentNo} transferred & synced to database!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _openAppointmentDetail(AppointmentItem appt) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: appt),
      ),
    );
    if (result == true) {
      _loadLiveAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _currentBackgroundColor,
      drawer: _buildDrawer(),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // Full-Width Top Bar that scrolls up and slowly disappears
            SliverAppBar(
              expandedHeight: 90.0,
              floating: true,
              pinned: false,
              snap: false,
              backgroundColor: _currentPrimaryDark,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              shadowColor: _currentPrimaryDark.withValues(alpha: 0.3),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: _currentPrimaryGradient,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: _availabilityMode == DoctorAvailabilityMode.emergency
                        ? Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5), width: 1.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: _currentPrimaryDark.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Integrated Menu Button
                          IconButton(
                            icon: const Icon(Icons.menu, size: 28, color: Colors.white),
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                            tooltip: 'Open Menu',
                          ),
                          const SizedBox(width: 8),

                          // Ashwini Header Title & Availability Status Badge
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.userProfile?.name ?? 'Dr. Rajesh V. Sharma',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.userProfile?.qualification ?? 'Senior Consultant Physician',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _availabilityMode == DoctorAvailabilityMode.emergency
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.35),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _availabilityMode == DoctorAvailabilityMode.emergency
                                            ? 'EMERGENCY DND'
                                            : (_availabilityMode == DoctorAvailabilityMode.notAvailable
                                                ? 'OFF DUTY'
                                                : 'AVAILABLE'),
                                        style: TextStyle(
                                          color: _availabilityMode == DoctorAvailabilityMode.emergency
                                              ? const Color(0xFFDC2626)
                                              : Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Logo Box on far right
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                AppAssets.logo,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.local_hospital, color: _currentPrimaryColor),
                              ),
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
            // Mode Banner if Emergency or Off-Duty
            if (_availabilityMode == DoctorAvailabilityMode.emergency) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMERGENCY CRITICAL MODE ACTIVE',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Doctor engaged in critical procedure. Notifications & calls BLOCKED.',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _availabilityMode = DoctorAvailabilityMode.available);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency mode exited. Availability restored to Available (Purple).'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'EXIT DND',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_availabilityMode == DoctorAvailabilityMode.notAvailable) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B5563),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Hospital Status: Not Available (Grey Mode)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _availabilityMode = DoctorAvailabilityMode.available);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Go Available',
                          style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Top Action Buttons Bar (Squarish Modern Badges with Text at Bottom)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  // QR Button (Always Purple)
                  Expanded(
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimaryToDeep,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => QrWorkflowScreen(existingAppointments: _appointments)),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12), // Squarish icon container
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: 26, // Larger icon
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'QR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // CALENDAR Button (Always Deep Royal Purple)
                  Expanded(
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B21B6), Color(0xFF3B0764)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const DoctorDutyScheduleScreen()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12), // Squarish icon container
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 26, // Larger icon
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'CALENDAR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // EMERGENCY Button
                  Expanded(
                    child: Container(
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const PandemicAlertScreen()),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12), // Squarish icon container
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 26, // Larger icon
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Appointments Container / List Section
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
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
                            Icon(Icons.calendar_today_rounded, size: 20, color: _currentPrimaryColor),
                            const SizedBox(width: 10),
                            const Text(
                              'Patient Appointments',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.headingText,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: _currentPrimaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _currentPrimaryColor.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_appointments.length} Active${_availabilityMode == DoctorAvailabilityMode.emergency ? " (DND)" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // List of Visually Attractive Appointment Cards
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadLiveAppointments,
                        child: _isLoadingAppointments && _appointments.isEmpty
                            ? const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              )
                            : _appointments.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 60),
                                      Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.task_alt, size: 52, color: AppColors.success),
                                            SizedBox(height: 10),
                                            Text(
                                              'No appointments scheduled for today',
                                              style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: _appointments.length,
                                    itemBuilder: (context, index) {
                                      final appt = _appointments[index];
                                      return _buildAppointmentCard(appt, index);
                                    },
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
    );
  }

  /// Visually Attractive Compact Card with Unified Theme & Streamlined Info
  Widget _buildAppointmentCard(AppointmentItem appt, int index) {
    final patientInitial = appt.patientName.isNotEmpty ? appt.patientName[0].toUpperCase() : 'P';
    final isCompleted = appt.isCompleted;

    Color statusBg;
    Color statusText;
    Color statusBorder;
    IconData statusIcon;
    String statusLabel;

    if (isCompleted) {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF059669);
      statusBorder = const Color(0xFFA7F3D0);
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'COMPLETED';
    } else if (appt.status.toLowerCase() == 'in_progress') {
      statusBg = const Color(0xFFFFFBEB);
      statusText = const Color(0xFFD97706);
      statusBorder = const Color(0xFFFDE68A);
      statusIcon = Icons.timelapse_rounded;
      statusLabel = 'IN PROGRESS';
    } else {
      statusBg = const Color(0xFFF8FAFC);
      statusText = const Color(0xFF475569);
      statusBorder = const Color(0xFFE2E8F0);
      statusIcon = Icons.schedule_rounded;
      statusLabel = appt.status.toUpperCase();
    }

    return Dismissible(
      key: Key(appt.id),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (appt.isCompleted) {
            // Remove completed consultation from doctor's screen only (not database)
            setState(() {
              _dismissedAppointmentIds.add(appt.id);
              _appointments.removeWhere((a) => a.id == appt.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Completed consultation for ${appt.patientName} removed from your screen.'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return true;
          } else {
            _openAppointmentDetail(appt);
            return false;
          }
        } else if (direction == DismissDirection.endToStart) {
          _transferAppointment(index);
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: appt.isCompleted ? const Color(0xFFDCFCE7) : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (appt.isCompleted ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              appt.isCompleted ? Icons.check_circle_rounded : Icons.touch_app_rounded,
              color: appt.isCompleted ? AppColors.success : AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              appt.isCompleted
                  ? 'Remove Completed'
                  : 'Open Rx & Details',
              style: TextStyle(
                color: appt.isCompleted ? const Color(0xFF15803D) : AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.infoBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.3), width: 1.2),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Transfer Appointment',
              style: TextStyle(color: AppColors.info, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(width: 8),
            Icon(Icons.swap_horizontal_circle_rounded, color: AppColors.info, size: 24),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () => _openAppointmentDetail(appt),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface, // Clean, uniform background for ALL cards
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCompleted ? const Color(0xFF10B981) : AppColors.primary).withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
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
              // Row 1: Avatar, Patient Info, Appt No & Delete Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Compact Avatar (34x34)
                  Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCompleted
                          ? const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF059669)])
                          : AppColors.gradientPrimaryToAccent,
                    ),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.surface,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: isCompleted ? const Color(0xFFECFDF5) : AppColors.primaryLight,
                        child: Text(
                          patientInitial,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? const Color(0xFF059669) : AppColors.primaryDark,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Patient Name, Meta, and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                appt.patientName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.headingText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusBorder, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 10.5, color: statusText),
                                  const SizedBox(width: 3),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: statusText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Subtitle line: Age, Gender, Blood group, Appt No, MRN
                        Row(
                          children: [
                            Text(
                              '${appt.age} yrs, ${appt.gender}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.bodyText,
                              ),
                            ),
                            if (appt.bloodGroup != null) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFFECACA), width: 0.6),
                                ),
                                child: Text(
                                  appt.bloodGroup!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                appt.appointmentNo,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            if (appt.medicalRecordNumber != null) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'MRN: ${appt.medicalRecordNumber}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Compact Delete Button (28x28)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 15),
                      onPressed: () => _deleteAppointment(index),
                      tooltip: 'Delete Appointment',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 7),

              // Row 2: Diagnosis Line (Compact, 1 line)
              Row(
                children: [
                  const Icon(Icons.health_and_safety_outlined, size: 13, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appt.diagnosis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Row 3: Badges Wrap: Payment Status, Mode & Admission (All combined in 1 row)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Payment Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: appt.isPaid ? AppColors.successBg : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: appt.isPaid
                            ? AppColors.success.withValues(alpha: 0.5)
                            : AppColors.warning.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appt.isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                          size: 11.5,
                          color: appt.isPaid ? AppColors.success : AppColors.warningText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appt.paymentStatus,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: appt.isPaid ? AppColors.successText : AppColors.warningText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Appointment Mode Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: appt.mode == AppointmentMode.teleconsultation
                          ? AppColors.infoBg
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: appt.mode == AppointmentMode.teleconsultation
                            ? AppColors.info.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appt.mode == AppointmentMode.teleconsultation
                              ? Icons.videocam_rounded
                              : Icons.qr_code_scanner_rounded,
                          size: 11.5,
                          color: appt.mode == AppointmentMode.teleconsultation
                              ? AppColors.info
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appt.mode == AppointmentMode.teleconsultation ? 'Teleconsult' : 'In-Person',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: appt.mode == AppointmentMode.teleconsultation
                                ? AppColors.info
                                : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Admission Status Pill (Integrated cleanly into the same row)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: appt.isAdmitted
                          ? AppColors.primaryLight.withValues(alpha: 0.6)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: appt.isAdmitted
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appt.isAdmitted ? Icons.single_bed_rounded : Icons.medical_services_outlined,
                          size: 11.5,
                          color: appt.isAdmitted ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          appt.isAdmitted
                              ? (appt.roomNo != null ? 'Admitted (${appt.roomNo})' : 'Admitted')
                              : 'Outpatient (OPD)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: appt.isAdmitted ? AppColors.primaryDark : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 4: Action Buttons (Height 36px, fits gracefully with no truncation)
              Row(
                children: [
                  // Auto-Fetch Rx Second Opinion Verification Button
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => openAutoPrescriptionReviewModal(context: context, appt: appt),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primaryDark),
                                SizedBox(width: 4),
                                Text(
                                  '2nd Opinion',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Action Button: "FILL PRESCRIPTION" or "VIEW PRESCRIPTION"
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: isCompleted
                            ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF047857)])
                            : AppColors.gradientPrimaryToDeep,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (isCompleted ? const Color(0xFF059669) : AppColors.primary).withValues(alpha: 0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openAppointmentDetail(appt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCompleted ? Icons.task_alt_rounded : Icons.edit_note_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isCompleted ? 'VIEW PRESCRIPTION' : 'FILL PRESCRIPTION',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Row 5: Subtle Swipe Hint (Single sleek 9.5px line, no 35px bulky container)
              Center(
                child: Text(
                  isCompleted
                      ? 'Swipe right to remove  •  Swipe left to transfer'
                      : 'Swipe right for details  •  Swipe left to transfer',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigation Drawer for Doctor Framework
  Widget _buildDrawer() {
    final profile = widget.userProfile ?? UserProfile.dbRecords['1234567890']!;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Executive Doctor Profile Drawer Header with Close (X) Button & Upper Image Positioning
          Container(
            padding: const EdgeInsets.fromLTRB(18, 38, 16, 18),
            decoration: BoxDecoration(
              gradient: _currentPrimaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Profile Avatar (Upper side) & Close (X) Button (Pushed a little above)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor Profile Picture Box
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          profile.profileImagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.person, size: 32, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ),

                    // Top Right Close (X) Button - PUSHED A LITTLE ABOVE
                    Transform.translate(
                      offset: const Offset(4, -18),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close Menu',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Doctor Name (No text overlap)
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),

                // Doctor Qualification
                Text(
                  profile.qualification,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),

                // Designation Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    profile.designation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Doctor License Badge & Chamber Details
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (profile.licenseNumber != null && profile.licenseNumber!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_user_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Lic: ${profile.licenseNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (profile.chamber != null && profile.chamber!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              profile.chamber!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (profile.shiftTiming != null && profile.shiftTiming!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              profile.shiftTiming!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3-Option Hospital Availability & Emergency Toggle Button
                _buildAvailabilityToggle(),

                const SizedBox(height: 8),

                // Status Indicator Strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _availabilityMode == DoctorAvailabilityMode.emergency
                            ? Icons.do_not_disturb_on_rounded
                            : (_availabilityMode == DoctorAvailabilityMode.notAvailable
                                ? Icons.person_off_rounded
                                : Icons.check_circle_rounded),
                        color: _availabilityMode == DoctorAvailabilityMode.emergency
                            ? Colors.yellowAccent
                            : Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _availabilityMode == DoctorAvailabilityMode.emergency
                              ? 'EMERGENCY MODE • Calls & alerts BLOCKED'
                              : (_availabilityMode == DoctorAvailabilityMode.notAvailable
                                  ? 'Off Duty / Not in Hospital (Grey Mode)'
                                  : 'Available in Hospital (Purple Mode)'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: _availabilityMode == DoctorAvailabilityMode.emergency
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.medical_information_outlined, color: _currentPrimaryColor),
            title: const Text('Pharmacy Stock'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PharmacyStockScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.forum_outlined, color: _currentPrimaryColor),
            title: const Text('Colleague Consult'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ColleagueConsultScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.meeting_room_outlined, color: _currentPrimaryColor),
            title: const Text('Available Rooms and Machine Records'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MachineRecordsScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text('Logout', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }

  /// 3-Option Availability Toggle Widget
  Widget _buildAvailabilityToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        children: [
          // 1st Option: Not Available for the hospital (Grey)
          _buildToggleOptionItem(
            mode: DoctorAvailabilityMode.notAvailable,
            title: 'Not Available',
            icon: Icons.person_off_rounded,
            activeBgColor: const Color(0xFF6B7280),
            activeTextColor: Colors.white,
          ),
          const SizedBox(width: 4),
          // 2nd Option: Available in hospital (Purple)
          _buildToggleOptionItem(
            mode: DoctorAvailabilityMode.available,
            title: 'Available',
            icon: Icons.check_circle_rounded,
            activeBgColor: AppColors.primary,
            activeTextColor: Colors.white,
          ),
          const SizedBox(width: 4),
          // 3rd Option: Emergency (Red + Calls & Notifications Blocked)
          _buildToggleOptionItem(
            mode: DoctorAvailabilityMode.emergency,
            title: 'Emergency',
            icon: Icons.crisis_alert_rounded,
            activeBgColor: const Color(0xFFDC2626),
            activeTextColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOptionItem({
    required DoctorAvailabilityMode mode,
    required String title,
    required IconData icon,
    required Color activeBgColor,
    required Color activeTextColor,
  }) {
    final isSelected = _availabilityMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _availabilityMode = mode;
          });

          String snackMessage;
          Color snackBg;
          if (mode == DoctorAvailabilityMode.emergency) {
            snackMessage = 'CRITICAL EMERGENCY MODE ACTIVE: All notifications, calls & alerts are BLOCKED!';
            snackBg = const Color(0xFFDC2626);
          } else if (mode == DoctorAvailabilityMode.notAvailable) {
            snackMessage = 'Doctor Status: Not Available for Hospital (Grey Mode Active).';
            snackBg = const Color(0xFF4B5563);
          } else {
            snackMessage = 'Doctor Status: Available in Hospital (Purple Mode Active).';
            snackBg = AppColors.primary;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    mode == DoctorAvailabilityMode.emergency
                        ? Icons.do_not_disturb_on_rounded
                        : (mode == DoctorAvailabilityMode.notAvailable
                            ? Icons.person_off_rounded
                            : Icons.check_circle_rounded),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      snackMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: snackBg,
              duration: const Duration(seconds: 3),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeTextColor : Colors.white70,
              ),
              const SizedBox(height: 3),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTextColor : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
