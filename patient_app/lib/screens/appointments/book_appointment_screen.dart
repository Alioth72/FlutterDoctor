import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/health_profile_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/mock_doctor_service.dart';
import '../../services/patient_database_service.dart';
import '../../widgets/dynamic_translated_text.dart';
import 'appointment_receipt_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Doctor? preselectedDoctor;

  const BookAppointmentScreen({
    super.key,
    this.preselectedDoctor,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _doctorService = MockDoctorService();
  final _patientDbService = PatientDatabaseService();
  final _reasonController = TextEditingController();

  List<Doctor> _doctors = [];
  List<String> _specialties = [];
  String _selectedSpecialty = 'All';
  bool _isLoading = true;

  Doctor? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot = '09:00 AM';
  bool _isBooking = false;
  String _selectedAppointmentType = 'Online';

  List<DoctorAvailabilitySlot> _availableSlots = [];
  bool _isLoadingSlots = false;

  final List<String> _quickReasons = const [
    'General Checkup',
    'Fever & Cough',
    'Body Pain',
    'Follow-up Visit',
    'Prescription Renewal',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.preselectedDoctor;
    _loadDoctors();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctorSlots() async {
    if (_selectedDoctor == null) return;
    setState(() {
      _isLoadingSlots = true;
    });

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final slots = await _patientDbService.fetchDoctorAvailability(_selectedDoctor!.id, dateStr);

    if (!mounted) return;

    final effectiveSlots = slots.isNotEmpty
        ? slots
        : _selectedDoctor!.availableTimeSlots.map((time) {
            return DoctorAvailabilitySlot(
              slotTime: time,
              timeLabel: time,
              capacity: 3,
              bookedCount: 0,
              remainingSpots: 3,
              status: 'available',
              isBookable: true,
              isPast: false,
            );
          }).toList();

    setState(() {
      _availableSlots = effectiveSlots;
      _isLoadingSlots = false;
      final currentMatch = effectiveSlots.where((s) => s.slotTime == _selectedTimeSlot).firstOrNull;
      if (currentMatch == null || !currentMatch.isBookable) {
        final firstBookable = effectiveSlots.where((s) => s.isBookable).firstOrNull;
        _selectedTimeSlot = firstBookable?.slotTime ?? (effectiveSlots.isNotEmpty ? effectiveSlots.first.slotTime : null);
      }
    });
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoading = true;
    });

    final specialties = _doctorService.getSpecialties();
    final doctors = await _doctorService.getDoctors(
      specialty: _selectedSpecialty == 'All' ? null : _selectedSpecialty,
    );

    setState(() {
      _specialties = specialties;
      _doctors = doctors;
      _isLoading = false;
      if (_selectedDoctor == null && doctors.isNotEmpty) {
        _selectedDoctor = doctors.first;
      }
      if (_selectedDoctor != null) {
        if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
          for (int i = 1; i <= 7; i++) {
            final nextDate = DateTime.now().add(Duration(days: i));
            if (_selectedDoctor!.isAvailableOn(nextDate)) {
              _selectedDate = nextDate;
              break;
            }
          }
        }
      }
    });

    if (_selectedDoctor != null) {
      _loadDoctorSlots();
    }
  }

  String _formatDate(DateTime date, [LanguageProvider? lang]) {
    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayStr = lang != null ? lang.tr(dayKeys[date.weekday - 1]) : dayKeys[date.weekday - 1];
    final monthStr = lang != null ? lang.tr('month_${date.month}') : '${date.month}';
    return '$dayStr, ${date.day} $monthStr';
  }

  Future<void> _handleConfirmBooking() async {
    if (_isBooking) return;
    FocusScope.of(context).unfocus();
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.tr('please_select_doctor'))),
      );
      return;
    }

    if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedDoctor!.name} ${lang.tr('doctor_not_available_day')}'),
        ),
      );
      return;
    }

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.tr('please_select_slot'))),
      );
      return;
    }

    final profileProvider = Provider.of<HealthProfileProvider>(context, listen: false);
    final patient = profileProvider.profile;

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.tr('profile_not_found_signup'))),
      );
      return;
    }

    setState(() {
      _isBooking = true;
    });

    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final fullDateString = '${days[_selectedDate.weekday - 1]}, ${_selectedDate.day.toString().padLeft(2, '0')} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';

    try {
      final appointment = await appointmentProvider.bookAppointment(
        doctor: _selectedDoctor!,
        patient: patient,
        appointmentDate: fullDateString,
        timeSlot: _selectedTimeSlot!,
        reason: _reasonController.text.trim().isEmpty ? 'General Consultation' : _reasonController.text.trim(),
        appointmentType: _selectedAppointmentType,
      );

      if (!mounted) return;

      setState(() {
        _isBooking = false;
      });

      // Navigate to digital receipt
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppointmentReceiptScreen(appointment: appointment),
        ),
      );
    } on SlotFullException catch (e) {
      if (!mounted) return;
      setState(() {
        _isBooking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      await _loadDoctorSlots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBooking = false;
      });
      final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanMsg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF9FAFC),
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: Text(
            lang.tr('book_appointment_title'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 160.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SPECIALTY Filter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('specialty_label'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSpecialty = 'All';
                              });
                              _loadDoctors();
                            },
                            child: Text(
                              '${lang.tr('view_all')} (${_specialties.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _specialties.map((spec) {
                            final isSelected = _selectedSpecialty == spec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedSpecialty = spec;
                                  });
                                  _loadDoctors();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                                      width: 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.02),
                                              offset: const Offset(0, 1),
                                              blurRadius: 3,
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                       if (isSelected) ...[
                                         const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                         const SizedBox(width: 4),
                                       ],
                                       DynamicTranslatedText(
                                         text: spec == 'All' ? lang.tr('cat_all') : spec,
                                         style: TextStyle(
                                           fontSize: 12.5,
                                           fontWeight: FontWeight.w700,
                                           color: isSelected ? Colors.white : const Color(0xFF1E293B),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),
                               ),
                             );
                           }).toList(),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // 2. AVAILABLE DOCTORS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('available_doctors'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_doctors.length} ${lang.tr('on_duty')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 155,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final doc = _doctors[index];
                            final isSelected = _selectedDoctor?.id == doc.id;
                            final initial = doc.name.replaceFirst('Dr. ', '').trim().isNotEmpty
                                ? doc.name.replaceFirst('Dr. ', '').trim()[0]
                                : 'D';

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDoctor = doc;
                                });
                                _loadDoctorSlots();
                              },
                              child: Container(
                                width: 300,
                                margin: const EdgeInsets.only(right: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
                                    width: isSelected ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.03),
                                      offset: const Offset(0, 6),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Doctor Details
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Avatar with online green dot
                                            Stack(
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF0D9488),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    initial,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 11,
                                                    height: 11,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  DynamicTranslatedText(
                                                    text: doc.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  DynamicTranslatedText(
                                                    text: doc.specialty,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF7C3AED),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on, size: 11, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 2),
                                                      Expanded(
                                                        child: DynamicTranslatedText(
                                                          text: doc.hospital,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: Color(0xFF64748B),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        // Bottom Row: Rating + Free Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${doc.rating}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 12,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Flexible(
                                                    child: Text(
                                                      ' (${doc.experienceYears} ${lang.tr('years_exp')})',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.0),
                                              ),
                                              child: Text(
                                                lang.tr('free_price'),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF059669),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Top Right Checkmark Badge (If Selected)
                                    if (isSelected)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF7C3AED),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: Colors.white,
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
                      const SizedBox(height: 22),

                      // 3. SELECT APPOINTMENT DATE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('select_date'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF7C3AED),
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDateCards(context),
                      const SizedBox(height: 22),

                      // 4. SELECT AVAILABLE TIME SLOT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('select_time_slot'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isLoadingSlots
                                  ? lang.tr('checking_slots')
                                  : '${_availableSlots.where((s) => s.isBookable).length} ${lang.tr('slots_free')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Sub-tabs
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFF7C3AED), width: 2.0),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  lang.tr('morning_afternoon'),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '|',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('shift_a_opd'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTimeSlotGrid(context),
                      const SizedBox(height: 22),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                lang.tr('appointment_type'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _selectedAppointmentType == 'Online'
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedAppointmentType == 'Online'
                                      ? const Color(0xFFA7F3D0)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _selectedAppointmentType == 'Online' ? '⚡ ${lang.tr('instant_video_room')}' : '🏥 ${lang.tr('hospital_queue_token')}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _selectedAppointmentType == 'Online'
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Online Option Card
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAppointmentType = 'Online';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _selectedAppointmentType == 'Online'
                                      ? const Color(0xFFFAF5FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedAppointmentType == 'Online'
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFFE5E7EB),
                                    width: _selectedAppointmentType == 'Online' ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedAppointmentType == 'Online'
                                          ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
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
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _selectedAppointmentType == 'Online'
                                                ? const Color(0xFF7C3AED)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.videocam_rounded,
                                            size: 20,
                                            color: _selectedAppointmentType == 'Online'
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (_selectedAppointmentType == 'Online')
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 18),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      lang.tr('online_video_title'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.tr('online_video_sub'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.25,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Offline Option Card
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAppointmentType = 'Offline';
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _selectedAppointmentType == 'Offline'
                                      ? const Color(0xFFF0FDF4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedAppointmentType == 'Offline'
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFE5E7EB),
                                    width: _selectedAppointmentType == 'Offline' ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _selectedAppointmentType == 'Offline'
                                          ? const Color(0xFF059669).withValues(alpha: 0.12)
                                          : Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
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
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _selectedAppointmentType == 'Offline'
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.local_hospital_rounded,
                                            size: 20,
                                            color: _selectedAppointmentType == 'Offline'
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                          ),
                                        ),
                                        if (_selectedAppointmentType == 'Offline')
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 18),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      lang.tr('offline_opd_title'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.tr('offline_opd_sub'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        height: 1.25,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // 5. REASON FOR VISIT (Optional)
                      Text(
                        lang.tr('reason_for_visit'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _quickReasons.map((reason) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _reasonController.text = reason;
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: DynamicTranslatedText(
                                    text: reason,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: lang.tr('reason_hint'),
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF7C3AED)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        // 6. BOTTOM STICKY BOOKING BAR
        bottomSheet: Container(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            18.0 + (MediaQuery.viewPaddingOf(context).bottom > 20
                ? (MediaQuery.viewPaddingOf(context).bottom * 0.35 + 6.0)
                : 0.0),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -4),
                blurRadius: 16,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summary Line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${lang.tr('slot_selected')}: ${_formatDate(_selectedDate, lang)} • ${_selectedTimeSlot ?? "09:00 AM"} • ${_selectedAppointmentType == 'Online' ? lang.tr('online_badge') : lang.tr('offline_badge')}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          DynamicTranslatedText(
                            text: '${_selectedDoctor?.name ?? "Dr. Ananya Sharma"} (OPD-1)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          lang.tr('total_fee'),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          lang.tr('free_price'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Confirm & Generate Token Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isBooking ? null : _handleConfirmBooking,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isBooking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _selectedAppointmentType == 'Online' ? lang.tr('confirm_online_appt') : lang.tr('confirm_token_appt'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
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
        ),
      ),
    );
  }

  /// Date selector cards matching mockup
  Widget _buildDateCards(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => now.add(Duration(days: i)));
    final lang = Provider.of<LanguageProvider>(context);
    final dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: days.map((date) {
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final isDoctorAvailable = _selectedDoctor?.isAvailableOn(date) ?? false;
          final isSunday = date.weekday == 7;

          return GestureDetector(
            onTap: isDoctorAvailable
                ? () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _loadDoctorSlots();
                  }
                : null,
            child: Container(
              width: 58,
              height: 82,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF7C3AED)
                    : isSunday
                        ? const Color(0xFFF8FAFC)
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFE5E7EB),
                  width: isSelected ? 2.0 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                          offset: const Offset(0, 6),
                          blurRadius: 12,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        lang.tr(dayKeys[date.weekday - 1]),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: isSelected
                              ? const Color(0xFFE9D5FF)
                              : isSunday
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white
                          : isSunday
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isSelected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  else if (!isDoctorAvailable || isSunday)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        lang.tr('off'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF43F5E),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Time slots 3-column grid matching mockup
  Widget _buildTimeSlotGrid(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    if (_selectedDoctor == null) {
      return Text(lang.tr('select_doctor_first'));
    }

    if (_isLoadingSlots) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 12),
            Text(
              lang.tr('checking_availability'),
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_selectedDoctor!.name} ${lang.tr('doctor_not_available_date')}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9F1239)),
              ),
            ),
          ],
        ),
      );
    }

    List<DoctorAvailabilitySlot> slots = _availableSlots;
    if (slots.isEmpty && _selectedDoctor != null) {
      slots = _selectedDoctor!.availableTimeSlots.map((time) {
        return DoctorAvailabilitySlot(
          slotTime: time,
          timeLabel: time,
          capacity: 3,
          bookedCount: 0,
          remainingSpots: 3,
          status: 'available',
          isBookable: true,
          isPast: false,
        );
      }).toList();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.85,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = _selectedTimeSlot == slot.slotTime;
        final isFull = slot.isFull;

        String statusLabel;
        Color statusColor;
        if (isFull) {
          statusLabel = lang.tr('slot_full');
          statusColor = const Color(0xFFEF4444);
        } else if (slot.remainingSpots == 1) {
          statusLabel = '1 ${lang.tr('spot_left')}';
          statusColor = const Color(0xFFD97706);
        } else if (slot.remainingSpots == 2) {
          statusLabel = '2 ${lang.tr('spots_left')}';
          statusColor = const Color(0xFF0D9488);
        } else {
          statusLabel = '3 ${lang.tr('spots_free')}';
          statusColor = const Color(0xFF059669);
        }

        return InkWell(
          onTap: isFull
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${slot.slotTime} ${lang.tr('slot_fully_booked')}'),
                      backgroundColor: const Color(0xFFEF4444),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              : () {
                  setState(() {
                    _selectedTimeSlot = slot.slotTime;
                  });
                },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isFull
                  ? const Color(0xFFF1F5F9)
                  : isSelected
                      ? const Color(0xFF7C3AED)
                      : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFull
                    ? const Color(0xFFE2E8F0)
                    : isSelected
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFFE5E7EB),
                width: isSelected ? 2.0 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.slotTime,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w900,
                        color: isFull
                            ? const Color(0xFF94A3B8)
                            : isSelected
                                ? Colors.white
                                : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSelected ? lang.tr('slot_selected') : statusLabel,
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? const Color(0xFFDDD6FE)
                            : isFull
                                ? const Color(0xFFEF4444)
                                : statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
