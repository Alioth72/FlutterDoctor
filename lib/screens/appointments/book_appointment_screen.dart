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
  String? _selectedTimeSlot;
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
    });
  }

  String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
    final appointment = await appointmentProvider.bookAppointment(
      doctor: _selectedDoctor!,
      patient: patient,
      appointmentDate: _formatDate(_selectedDate),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Book Appointment'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Specialty Filter
                      Text(
                        'Select Specialty',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _specialties.map((spec) {
                            final isSelected = _selectedSpecialty == spec;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(spec),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedSpecialty = spec;
                                    });
                                    _loadDoctors();
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Select Doctor
                      Text(
                        'Available Doctors',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 155,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final doc = _doctors[index];
                            final isSelected = _selectedDoctor?.id == doc.id;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDoctor = doc;
                                  _selectedTimeSlot = null;
                                });
                              },
                              child: Container(
                                width: 270,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: colorScheme.primary,
                                          child: Text(
                                            doc.name.split(' ').length > 1
                                                ? doc.name.split(' ')[1][0]
                                                : 'D',
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                doc.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text(
                                                doc.specialty,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doc.hospital,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star, size: 14, color: Colors.amber),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  '${doc.rating} (${doc.experienceYears}y exp)',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Text(
                                          'Free (₹0)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
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
                      ),
                      const SizedBox(height: 24),

                      // 3. Availability Calendar (Dates)
                      Text(
                        'Select Appointment Date',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildHorizontalCalendar(context),
                      const SizedBox(height: 20),

                      // 4. Time Slots
                      Text(
                        'Select Available Time Slot',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeSlots(context),
                      const SizedBox(height: 20),

                      // 5. Reason for Consultation
                      Text(
                        'Reason for Visit (Optional)',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _quickReasons.map((reason) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ActionChip(
                                label: Text(reason, style: const TextStyle(fontSize: 12)),
                                onPressed: () {
                                  setState(() {
                                    _reasonController.text = reason;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        stylusHandwritingEnabled: false,
                        decoration: InputDecoration(
                          hintText: 'e.g. Fever, routine health checkup',
                          prefixIcon: const Icon(Icons.edit_note),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton(
              onPressed: _isBooking ? null : _handleConfirmBooking,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isBooking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _selectedTimeSlot != null
                          ? 'Confirm for $_selectedTimeSlot (₹0)'
                          : 'Confirm & Generate Receipt (₹0)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCalendar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    // 10 upcoming days
    final days = List.generate(10, (i) => now.add(Duration(days: i)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final isDoctorAvailable = _selectedDoctor?.isAvailableOn(date) ?? false;

          return GestureDetector(
            onTap: isDoctorAvailable
                ? () {
                    setState(() {
                      _selectedDate = date;
                      _selectedTimeSlot = null;
                    });
                  }
                : null,
            child: Container(
              width: 58,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary
                    : isDoctorAvailable
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : isDoctorAvailable
                              ? colorScheme.onSurface
                              : colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : isDoctorAvailable
                              ? colorScheme.onSurface
                              : colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!isDoctorAvailable)
                    Text(
                      'Off',
                      style: TextStyle(fontSize: 10, color: colorScheme.error),
                    )
                  else
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.onPrimary : Colors.green,
                        shape: BoxShape.circle,
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

  Widget _buildTimeSlots(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_selectedDoctor == null) {
      return const Text('Select a doctor first.');
    }

    if (!_selectedDoctor!.isAvailableOn(_selectedDate)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_selectedDoctor!.name} is not available on this date. Please choose an active date from the calendar.',
                style: TextStyle(fontSize: 12, color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      );
    }

    final slots = _selectedDoctor!.availableTimeSlots;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;
        return ChoiceChip(
          label: Text(slot),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedTimeSlot = selected ? slot : null;
            });
          },
        );
      }).toList(),
    );
  }
}
