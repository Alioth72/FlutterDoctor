import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/doctor.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/health_profile_provider.dart';
import '../../services/mock_doctor_service.dart';
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
  final _reasonController = TextEditingController();

  List<Doctor> _doctors = [];
  List<String> _specialties = [];
  String _selectedSpecialty = 'All';
  bool _isLoading = true;

  Doctor? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot = '09:00 AM';
  bool _isBooking = false;

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
        if (_selectedDoctor!.availableTimeSlots.isNotEmpty) {
          _selectedTimeSlot ??= _selectedDoctor!.availableTimeSlots.first;
        }
      }
    });
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Future<void> _handleConfirmBooking() async {
    FocusScope.of(context).unfocus();

    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor')),
      );
      return;
    }

    if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedDoctor!.name} is not available on this day. Please pick another date.'),
        ),
      );
      return;
    }

    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an available time slot')),
      );
      return;
    }

    final profileProvider = Provider.of<HealthProfileProvider>(context, listen: false);
    final patient = profileProvider.profile;

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient profile not found. Please complete signup first.')),
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

    final appointment = await appointmentProvider.bookAppointment(
      doctor: _selectedDoctor!,
      patient: patient,
      appointmentDate: fullDateString,
      timeSlot: _selectedTimeSlot!,
      reason: _reasonController.text.trim().isEmpty ? 'General Consultation' : _reasonController.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
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
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
          title: const Text(
            'Book Appointment',
            style: TextStyle(
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
                          const Text(
                            'SPECIALTY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSpecialty = 'All';
                              });
                              _loadDoctors();
                            },
                            child: Text(
                              'View All (${_specialties.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6D28D9),
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
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF6D28D9) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
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
                                      Text(
                                        spec,
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
                          const Text(
                            'Available Doctors',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_doctors.length} on duty',
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
                                  if (!doc.availableTimeSlots.contains(_selectedTimeSlot)) {
                                    _selectedTimeSlot = doc.availableTimeSlots.isNotEmpty
                                        ? doc.availableTimeSlots.first
                                        : null;
                                  }
                                });
                              },
                              child: Container(
                                width: 300,
                                margin: const EdgeInsets.only(right: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2.0 : 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? const Color(0xFF6D28D9).withValues(alpha: 0.08)
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
                                                    borderRadius: BorderRadius.circular(14),
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
                                                  Text(
                                                    doc.name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    doc.specialty,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF6D28D9),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on, size: 11, color: Color(0xFF64748B)),
                                                      const SizedBox(width: 2),
                                                      Expanded(
                                                        child: Text(
                                                          doc.hospital,
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
                                                      ' (${doc.experienceYears}y exp)',
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
                                              child: const Text(
                                                'Free (₹0)',
                                                style: TextStyle(
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
                                            color: Color(0xFF6D28D9),
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
                          const Text(
                            'Select Appointment Date',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFF6D28D9),
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
                          const Text(
                            'Select Available Time Slot',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              '7 slots free',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Sub-tabs
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.only(bottom: 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFF6D28D9), width: 2.0),
                              ),
                            ),
                            child: const Text(
                              'Morning & Afternoon',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '|',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Shift A (General OPD)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTimeSlotGrid(context),
                      const SizedBox(height: 22),

                      // 5. REASON FOR VISIT (Optional)
                      const Text(
                        'Reason for Visit (Optional)',
                        style: TextStyle(
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
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    reason,
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
                          hintText: 'e.g. Fever, routine health checkup',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6D28D9)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
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
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                            'Selected: ${_formatDate(_selectedDate)} • ${_selectedTimeSlot ?? "09:00 AM"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_selectedDoctor?.name ?? "Dr. Ananya Sharma"} (OPD-1)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL FEE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Free (₹0)',
                          style: TextStyle(
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
                      backgroundColor: const Color(0xFF6D28D9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF6D28D9).withValues(alpha: 0.4),
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 20, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Confirm & Generate Token (₹0)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                  color: Colors.white,
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
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

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
                  }
                : null,
            child: Container(
              width: 58,
              height: 82,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6D28D9)
                    : isSunday
                        ? const Color(0xFFF8FAFC)
                        : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6D28D9)
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2.0 : 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
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
                  Text(
                    dayNames[date.weekday - 1],
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
                    const Text(
                      'Off',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF43F5E),
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
    if (_selectedDoctor == null) {
      return const Text('Select a doctor first.');
    }

    if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE4E6)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFE11D48), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_selectedDoctor!.name} is not available on this date. Please choose an active date from above.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9F1239)),
              ),
            ),
          ],
        ),
      );
    }

    final slots = _selectedDoctor!.availableTimeSlots;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = _selectedTimeSlot == slot;

        // Subtitle tag like "Available", "Fast filling", "Afternoon"
        String statusLabel = 'Available';
        Color statusColor = const Color(0xFF059669);

        if (index == 2) {
          statusLabel = 'Fast filling';
          statusColor = const Color(0xFFD97706);
        } else if (slot.contains('PM')) {
          statusLabel = 'Afternoon';
          statusColor = const Color(0xFF0D9488);
        }

        return InkWell(
          onTap: () {
            setState(() {
              _selectedTimeSlot = slot;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6D28D9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                width: isSelected ? 2.0 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSelected ? 'Selected' : statusLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFFDDD6FE) : statusColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
