import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DutyShiftItem {
  final String id;
  final String hospitalName;
  final String department;
  final String roomNo;
  final DateTime date;
  final String startTime;
  final String endTime;
  final bool isAdminAssigned;
  final String assignedBy;

  DutyShiftItem({
    required this.id,
    required this.hospitalName,
    required this.department,
    required this.roomNo,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isAdminAssigned,
    required this.assignedBy,
  });
}

class DoctorDutyScheduleScreen extends StatefulWidget {
  const DoctorDutyScheduleScreen({super.key});

  @override
  State<DoctorDutyScheduleScreen> createState() => _DoctorDutyScheduleScreenState();
}

class _DoctorDutyScheduleScreenState extends State<DoctorDutyScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  late List<DutyShiftItem> _shifts;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _shifts = [
      DutyShiftItem(
        id: '1',
        hospitalName: 'Ashwini Central Hospital',
        department: 'General OPD & Cardiology',
        roomNo: 'OPD Chamber 104',
        date: today,
        startTime: '09:00 AM',
        endTime: '02:00 PM',
        isAdminAssigned: true,
        assignedBy: 'Admin Vikram Sethi',
      ),
      DutyShiftItem(
        id: '2',
        hospitalName: 'Metro Healthcare OPD',
        department: 'Consultant Clinic',
        roomNo: 'Chamber 08',
        date: today,
        startTime: '05:00 PM',
        endTime: '08:30 PM',
        isAdminAssigned: false,
        assignedBy: 'Self-Scheduled (Dr. Rajesh)',
      ),
      DutyShiftItem(
        id: '3',
        hospitalName: 'Ashwini Emergency Hub',
        department: 'Trauma & ICU Ward',
        roomNo: 'ICU Unit 02',
        date: today.add(const Duration(days: 1)),
        startTime: '08:00 AM',
        endTime: '04:00 PM',
        isAdminAssigned: true,
        assignedBy: 'Admin Vikram Sethi',
      ),
      DutyShiftItem(
        id: '4',
        hospitalName: 'City Care Dispensary',
        department: 'Internal Medicine OPD',
        roomNo: 'Room 202',
        date: today.add(const Duration(days: 2)),
        startTime: '10:00 AM',
        endTime: '03:00 PM',
        isAdminAssigned: false,
        assignedBy: 'Self-Scheduled (Dr. Rajesh)',
      ),
    ];
  }

  void _addSelfScheduledShift() {
    final hospitalCtrl = TextEditingController(text: 'Ashwini Central Hospital');
    final deptCtrl = TextEditingController(text: 'General OPD');
    final roomCtrl = TextEditingController(text: 'Room 105');
    DateTime shiftDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 14, minute: 0);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.edit_calendar_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Self-Schedule Duty Shift', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: hospitalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hospital / Clinic Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: roomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'OPD / Room No',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Picker Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: shiftDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            shiftDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text('Duty Date: ${shiftDate.day}/${shiftDate.month}/${shiftDate.year}'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Time Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: startTime);
                              if (picked != null) {
                                setModalState(() => startTime = picked);
                              }
                            },
                            child: Text('Start: ${startTime.format(context)}', style: const TextStyle(fontSize: 11.5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: endTime);
                              if (picked != null) {
                                setModalState(() => endTime = picked);
                              }
                            },
                            child: Text('End: ${endTime.format(context)}', style: const TextStyle(fontSize: 11.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (hospitalCtrl.text.isNotEmpty) {
                      setState(() {
                        _shifts.add(
                          DutyShiftItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            hospitalName: hospitalCtrl.text,
                            department: deptCtrl.text,
                            roomNo: roomCtrl.text,
                            date: shiftDate,
                            startTime: startTime.format(context),
                            endTime: endTime.format(context),
                            isAdminAssigned: false,
                            assignedBy: 'Self-Scheduled (Dr. Rajesh)',
                          ),
                        );
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Duty shift self-scheduled & added to roster!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Shift'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter shifts for current selected date
    final selectedShifts = _shifts.where((s) =>
        s.date.year == _selectedDate.year &&
        s.date.month == _selectedDate.month &&
        s.date.day == _selectedDate.day).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hospital Duty Schedule'),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
            tooltip: 'Pick Date via Calendar',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                        onPrimary: Colors.white,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSelfScheduledShift,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Self-Schedule Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Horizontal Calendar Date Strip Selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: 74,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 14,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index - 2));
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;

                  final weekDayStr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.gradientPrimaryToDeep : null,
                        color: isSelected ? null : AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekDayStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white70 : AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.headingText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Selected Date Roster Summary Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Schedule for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedShifts.length} Shift(s)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Duty Shifts List
          Expanded(
            child: selectedShifts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_available_rounded, size: 56, color: AppColors.muted),
                        const SizedBox(height: 12),
                        const Text(
                          'No hospital duty shifts scheduled for this date.',
                          style: TextStyle(fontSize: 13.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _addSelfScheduledShift,
                          icon: const Icon(Icons.add, color: AppColors.primary),
                          label: const Text('Self-Schedule Shift Now'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: selectedShifts.length,
                    itemBuilder: (context, index) {
                      final shift = selectedShifts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: shift.isAdminAssigned
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.info.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Hospital Name & Assignment Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          shift.hospitalName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.headingText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: shift.isAdminAssigned ? AppColors.primaryLight : AppColors.infoBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: shift.isAdminAssigned ? AppColors.primary : AppColors.info,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        shift.isAdminAssigned ? Icons.admin_panel_settings : Icons.person_pin,
                                        size: 13,
                                        color: shift.isAdminAssigned ? AppColors.primaryDark : AppColors.info,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        shift.isAdminAssigned ? 'Admin Assigned' : 'Self-Scheduled',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: shift.isAdminAssigned ? AppColors.primaryDark : AppColors.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Department & Room No
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    shift.department,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.bodyText),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    shift.roomNo,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.headingText),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Timing Bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duty Shift Hours: ${shift.startTime} - ${shift.endTime}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Assignment Metadata Note
                            Text(
                              'Roster Status: ${shift.assignedBy}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.muted),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
