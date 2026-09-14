import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../models/appointment_model.dart';

import '../services/api_client.dart';
import '../teleconsult/data/appointment_repository.dart';
import '../teleconsult/screens/doctor_consent_screen.dart';

class AppointmentDetailScreen extends StatefulWidget {
  final AppointmentItem appointment;

  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _diagnosisController;
  late TextEditingController _familyHistoryController;
  late List<MedicineItem> _medicines;

  bool _isUpdatingStatus = false;

  DateTime? _scheduledFollowUpDate;
  String? _scheduledTimeSlot;
  String? _scheduledFollowUpNotes;

  // Referral State
  String? _referralHospital;
  String? _referralDepartment;
  String? _referralDoctor;
  String? _referralAppointmentNo;
  String? _referralUrgency;
  DateTime? _referralDate;
  String? _referralTimeSlot;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(
      text: widget.appointment.heightCm.toString(),
    );
    _weightController = TextEditingController(
      text: widget.appointment.weightKg.toString(),
    );
    _diagnosisController = TextEditingController(
      text: widget.appointment.diagnosis,
    );
    _familyHistoryController = TextEditingController(
      text: widget.appointment.familyHistory,
    );
    _medicines = List.from(widget.appointment.medicines);
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _diagnosisController.dispose();
    _familyHistoryController.dispose();
    super.dispose();
  }

  Future<void> _openTeleconsultation() async {
    if (Firebase.apps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Video consultation setup is unavailable. Restart the app and try again.',
          ),
        ),
      );
      return;
    }

    final repository = DoctorAppointmentRepository(widget.appointment);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorConsentScreen(
          appointment: repository.appointment,
          repository: repository,
          firestore: FirebaseFirestore.instance,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _addMedicine() {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController();
        final doseCtrl = TextEditingController();
        final durCtrl = TextEditingController();
        final clinicCtrl = TextEditingController(
          text: 'Ashwini Central Pharmacy (Available)',
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add Medicine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medicine Name (e.g. Paracetamol 500mg)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosage (e.g. 1-0-1 after food)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: durCtrl,
                decoration: const InputDecoration(
                  labelText: 'Duration (e.g. 5 Days)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: clinicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Linked Clinic / Pharmacy',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    _medicines.add(
                      MedicineItem(
                        name: nameCtrl.text,
                        dosage: doseCtrl.text.isEmpty ? '1-0-1' : doseCtrl.text,
                        duration: durCtrl.text.isEmpty
                            ? '3 Days'
                            : durCtrl.text,
                        closestClinic: clinicCtrl.text,
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editDietarySuggestions(BuildContext context, AppointmentItem appt) {
    final dietCtrl = TextEditingController(text: appt.dietarySuggestions ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Update Food & Dietary Suggestions'),
          content: TextField(
            controller: dietCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter recommended food, meal plan, or dietary restrictions...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  appt.dietarySuggestions = dietCtrl.text;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addInpatientProcedure(BuildContext context, AppointmentItem appt) {
    final titleCtrl = TextEditingController();
    final timingCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'Injection';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Injection / Procedure Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Procedure / Inj. Name (e.g. Inj. Insulin 10IU)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: timingCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Timing Schedule (e.g. 08:00 AM & 08:00 PM)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nurse / Administration Instructions',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items:
                          [
                                'Injection',
                                'IV Drip',
                                'Nursing Care',
                                'Diagnostic Specimen',
                              ]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            category = val;
                          });
                        }
                      },
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
                    if (titleCtrl.text.isNotEmpty) {
                      setState(() {
                        appt.inpatientSchedules ??= [];
                        appt.inpatientSchedules!.add(
                          InpatientProcedureItem(
                            title: titleCtrl.text,
                            timing: timingCtrl.text.isEmpty
                                ? 'As Prescribed'
                                : timingCtrl.text,
                            instructions: notesCtrl.text.isEmpty
                                ? 'Follow standard protocol'
                                : notesCtrl.text,
                            category: category,
                          ),
                        );
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startConsultation() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final res = await ApiClient.updateAppointment(
        appointmentId: widget.appointment.id,
        status: 'in_progress',
        reason: _diagnosisController.text.isNotEmpty
            ? _diagnosisController.text
            : widget.appointment.diagnosis,
      );

      if (res['success'] == true) {
        setState(() {
          widget.appointment.status = 'in_progress';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Consultation started! Status is now IN PROGRESS.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${res['error'] ?? 'Could not start consultation'}',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _completeConsultation() async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    final height =
        double.tryParse(_heightController.text) ?? widget.appointment.heightCm;
    final weight =
        double.tryParse(_weightController.text) ?? widget.appointment.weightKg;
    final diag = _diagnosisController.text;
    final famHist = _familyHistoryController.text;

    try {
      final res = await ApiClient.updateAppointment(
        appointmentId: widget.appointment.id,
        status: 'completed',
        reason: diag.isNotEmpty ? diag : widget.appointment.diagnosis,
        notes: {
          'dietary_suggestions': widget.appointment.dietarySuggestions,
          'room_no': widget.appointment.roomNo,
          'is_admitted': widget.appointment.isAdmitted,
          'completed_at': DateTime.now().toIso8601String(),
        },
        prescriptions: _medicines.map((m) {
          final daysMatch = RegExp(r'\d+').firstMatch(m.duration);
          final days = daysMatch != null
              ? int.tryParse(daysMatch.group(0)!)
              : 5;
          return {
            'medication_name': m.name,
            'dosage': m.dosage,
            'frequency': m.dosage,
            'duration_days': (days != null && days > 0) ? days : 5,
            'route': 'oral',
            'closestClinic': m.closestClinic,
            'instructions': {'timing': m.dosage, 'clinic': m.closestClinic},
          };
        }).toList(),
      );

      if (res['success'] == true) {
        widget.appointment.isCompleted = true;
        widget.appointment.status = 'completed';
        widget.appointment.heightCm = height;
        widget.appointment.weightKg = weight;
        widget.appointment.diagnosis = diag;
        widget.appointment.familyHistory = famHist;
        widget.appointment.medicines = _medicines;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Consultation completed for ${widget.appointment.patientName} & synced to database!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${res['error'] ?? 'Failed to complete consultation'}',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _cancelAppointment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment'),
        content: Text(
          'Are you sure you want to cancel the appointment for ${widget.appointment.patientName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdatingStatus = true);
    try {
      final res = await ApiClient.updateAppointment(
        appointmentId: widget.appointment.id,
        status: 'cancelled',
      );
      if (res['success'] == true) {
        setState(() => widget.appointment.status = 'cancelled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment cancelled successfully.'),
              backgroundColor: AppColors.danger,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: ${res['error']}'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  bool _isAshaReferral(AppointmentItem appt) {
    final notes = appt.notes;
    if (notes == null) return false;
    return notes['referral_type'] == 'asha_referral' ||
        notes['vitals'] != null ||
        notes['asha_assessment_id'] != null;
  }

  Widget _buildAshaReferralCard(AppointmentItem appt) {
    final notes = appt.notes ?? {};
    final vitals = notes['vitals'] is Map
        ? Map<String, dynamic>.from(notes['vitals'] as Map)
        : <String, dynamic>{};
    final symptoms = notes['symptoms']?.toString() ?? '';
    final fieldCare = notes['field_care_advice']?.toString() ?? '';
    final referralReason = appt.reason ?? notes['reason']?.toString() ?? 'Field Referral';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ASHA FIELD REFERRAL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF5B21B6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFC4B5FD)),
                ),
                child: const Text(
                  'Pre-Assessed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Referral Reason: ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4C1D95),
                ),
              ),
              Expanded(
                child: Text(
                  referralReason,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (vitals.isNotEmpty) ...[
            const Text(
              'MEASURED FIELD VITALS (No Re-entry Needed):',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B21A8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (vitals['heart_rate_bpm'] != null)
                  _buildReferralVitalChip(
                    Icons.favorite_rounded,
                    '${vitals['heart_rate_bpm']} BPM (Camera rPPG)',
                    Colors.red.shade600,
                  ),
                if (vitals['blood_pressure'] != null)
                  _buildReferralVitalChip(
                    Icons.speed_rounded,
                    'BP: ${vitals['blood_pressure']} mmHg',
                    Colors.indigo.shade600,
                  ),
                if (vitals['spo2_percent'] != null)
                  _buildReferralVitalChip(
                    Icons.air_rounded,
                    'SpO2: ${vitals['spo2_percent']}%',
                    Colors.teal.shade700,
                  ),
                if (vitals['temperature_c'] != null)
                  _buildReferralVitalChip(
                    Icons.thermostat_rounded,
                    '${vitals['temperature_c']}°C',
                    Colors.amber.shade800,
                  ),
                if (vitals['blood_glucose_mg_dl'] != null)
                  _buildReferralVitalChip(
                    Icons.water_drop_rounded,
                    'Glu: ${vitals['blood_glucose_mg_dl']} mg/dL',
                    Colors.purple.shade700,
                  ),
                if (vitals['weight_kg'] != null)
                  _buildReferralVitalChip(
                    Icons.monitor_weight_rounded,
                    '${vitals['weight_kg']} kg',
                    Colors.blueGrey.shade700,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          if (symptoms.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Field Observations & Symptoms:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B21A8),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    symptoms,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (fieldCare.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ASHA Immediate Care Given in Field:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fieldCare,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferralVitalChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final isTeleconsult = appt.mode == AppointmentMode.teleconsultation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Appointment Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Appointment no. ${appt.appointmentNo}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.headingText,
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: appt.status == 'completed'
                                        ? AppColors.successBg
                                        : (appt.status == 'in_progress'
                                              ? const Color(0xFFFEF3C7)
                                              : AppColors.primaryLight),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: appt.status == 'completed'
                                          ? AppColors.success
                                          : (appt.status == 'in_progress'
                                                ? const Color(0xFFD97706)
                                                : AppColors.primary),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    appt.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: appt.status == 'completed'
                                          ? AppColors.successText
                                          : (appt.status == 'in_progress'
                                                ? const Color(0xFFB45309)
                                                : AppColors.primaryDark),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isTeleconsult
                                        ? AppColors.infoBg
                                        : AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isTeleconsult
                                            ? Icons.videocam_outlined
                                            : Icons.qr_code_scanner,
                                        size: 14,
                                        color: isTeleconsult
                                            ? AppColors.info
                                            : AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTeleconsult
                                            ? 'Teleconsult'
                                            : 'In-Person QR',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isTeleconsult
                                              ? AppColors.info
                                              : AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 18,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${appt.patientName} (${appt.age} yrs, ${appt.gender})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              ),
                            ),
                          ],
                        ),
                        if (appt.medicalRecordNumber != null ||
                            appt.bloodGroup != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (appt.medicalRecordNumber != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Text(
                                    'MRN: ${appt.medicalRecordNumber}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E40AF),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              if (appt.bloodGroup != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Text(
                                    'Blood: ${appt.bloodGroup}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TIMING: ${appt.timing}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.payment_outlined,
                              size: 16,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PAYMENT: ${appt.paymentStatus}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_isAshaReferral(appt)) ...[
                    _buildAshaReferralCard(appt),
                    const SizedBox(height: 16),
                  ],

                  // Patient History Section with Detailed History Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PATIENT HISTORY:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppColors.headingText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showDetailedVisitsHistoryModal(context, appt),
                        icon: const Icon(
                          Icons.history_edu_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Detailed History',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          backgroundColor: AppColors.primaryLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: appt.patientHistory.map((historyItem) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                historyItem,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.bodyText,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Inpatient Care Plan (If Patient is Admitted)
                  if (appt.isAdmitted) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Bed / Room details & Admission status badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.single_bed_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Inpatient Care Plan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.headingText,
                                        ),
                                      ),
                                      Text(
                                        appt.roomNo ?? 'Room N/A',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.success.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Currently Admitted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.successText,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // 1. Food / Dietary Suggestions Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.restaurant_rounded,
                                    size: 18,
                                    color: AppColors.warningText,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Food & Dietary Suggestions',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.headingText,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                onPressed: () =>
                                    _editDietarySuggestions(context, appt),
                                tooltip: 'Edit Diet Plan',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              appt.dietarySuggestions ??
                                  'No specific dietary restrictions logged.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.headingText,
                                height: 1.4,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 2. Inpatient Injection & Medicine Schedule Section
                          Row(
                            children: [
                              const Icon(
                                Icons.vaccines_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Injections & Procedures',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headingText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _addInpatientProcedure(context, appt),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // List of Injection/Procedure Items
                          if (appt.inpatientSchedules == null ||
                              appt.inpatientSchedules!.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No injections or IV schedules added yet.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: appt.inpatientSchedules!.map((proc) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(
                                      alpha: 0.4,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              proc.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              proc.category,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.schedule_rounded,
                                            size: 14,
                                            color: AppColors.muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Timing: ${proc.timing}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.headingText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Nurse Note: ${proc.instructions}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Prescription Section matching wireframe
                  const Text(
                    'Prescription:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Height & Weight Card
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Height (cm)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weight (kg)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                              TextField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Family History : Graph types matching wireframe
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Family History : Graph types',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.headingText,
                              ),
                            ),
                            Icon(
                              Icons.show_chart,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _familyHistoryController,
                          decoration: const InputDecoration(
                            hintText: 'Enter family history details...',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Diagnosis Field
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diagnosis',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _diagnosisController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Enter clinical diagnosis...',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Medicines Section -> link to hospital clinic or closest clinic
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Medicines',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.headingText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addMedicine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Medicine'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Column(
                    children: _medicines.map((med) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  med.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headingText,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    med.dosage,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Duration: ${med.duration}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_pharmacy_outlined,
                                  size: 14,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Linked Clinic: ${med.closestClinic}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Scheduled Follow-Up Date Banner if already scheduled
                if (_scheduledFollowUpDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Follow-Up Scheduled: ${_scheduledFollowUpDate!.day}/${_scheduledFollowUpDate!.month}/${_scheduledFollowUpDate!.year} (${_scheduledTimeSlot ?? "10:30 AM"})',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Referral Confirmation Banner if referral is active
                if (_referralHospital != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.swap_horizontal_circle_outlined,
                              size: 18,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Referral Scheduled: Appt #${_referralAppointmentNo ?? "REF-8092"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_referralHospital!} • ${_referralDepartment!} (${_referralDoctor ?? ""})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.headingText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // SCHEDULE FUTURE APPOINTMENT Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _scheduleFutureAppointment(context),
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _scheduledFollowUpDate == null
                          ? 'SCHEDULE FUTURE APPOINTMENT'
                          : 'RESCHEDULE FUTURE APPOINTMENT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // REFER TO ANOTHER HOSPITAL / DOCTOR Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReferralModalSheet(context),
                    icon: const Icon(
                      Icons.local_hospital_outlined,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      _referralHospital == null
                          ? 'REFER TO ANOTHER HOSPITAL / DOCTOR'
                          : 'MODIFY HOSPITAL REFERRAL',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // QR / TELECONSULTATION Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isTeleconsult
                        ? _openTeleconsultation
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Opening Patient QR Verification Scanner...',
                                ),
                              ),
                            );
                          },
                    icon: Icon(
                      isTeleconsult ? Icons.videocam : Icons.qr_code_scanner,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      isTeleconsult ? 'TELECONSULTATION ROOM' : 'QR SCANNER',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Clinical Action Buttons based on status:
                if (appt.status == 'queued' || appt.status == 'confirmed') ...[
                  // 1. START CONSULTATION
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus ? null : _startConsultation,
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isUpdatingStatus
                            ? 'STARTING CONSULTATION...'
                            : 'START CONSULTATION',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingStatus ? null : _cancelAppointment,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      label: const Text(
                        'CANCEL APPOINTMENT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.danger,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (appt.status == 'in_progress') ...[
                  // 2. COMPLETE CONSULTATION
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isUpdatingStatus
                          ? null
                          : _completeConsultation,
                      icon: _isUpdatingStatus
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.task_alt_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isUpdatingStatus
                            ? 'SYNCING CONSULTATION...'
                            : 'COMPLETE CONSULTATION',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.success.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isUpdatingStatus ? null : _cancelAppointment,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      label: const Text(
                        'CANCEL APPOINTMENT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.danger,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (appt.status == 'completed') ...[
                  // 3. ALREADY COMPLETED STATE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'CONSULTATION COMPLETED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successText,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (appt.status == 'cancelled') ...[
                  // 4. CANCELLED STATE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'APPOINTMENT CANCELLED',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.dangerText,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphPoint(String label, String val, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          val,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.headingText,
          ),
        ),
      ],
    );
  }

  /// Opens a detailed bottom sheet modal showing the full history of past patient visits
  void _showDetailedVisitsHistoryModal(
    BuildContext context,
    AppointmentItem appt,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.history_edu_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Past Visits & Clinical History',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headingText,
                                  ),
                                ),
                                Text(
                                  'Patient: ${appt.patientName} (${appt.gender}, ${appt.age} yrs)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.muted,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Visits Timeline
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _buildVisitTimelineCard(
                      date: '14 Aug 2026',
                      doctor: 'Dr. Rajesh V. Sharma (General Medicine)',
                      reason: 'Routine Diabetes & BP Follow-up',
                      diagnosis:
                          'Controlled Type 2 Diabetes, Mild Hypertension',
                      vitals:
                          'BP: 124/82 mmHg | Sugar: 118 mg/dL | HbA1c: 6.7%',
                      medicines: [
                        'Metformin 500mg (1-0-1)',
                        'Telmisartan 40mg (1-0-0)',
                      ],
                      notes: 'Patient compliant with diet. Maintain daily 30-min walking routine.',
                    ),
                    const SizedBox(height: 16),
                    _buildVisitTimelineCard(
                      date: '02 May 2026',
                      doctor: 'Dr. Suresh Nair (General Surgery)',
                      reason: 'Post-Op Appendectomy Clearance',
                      diagnosis: 'Surgical Incision Fully Healed',
                      vitals: 'BP: 120/78 mmHg | Pulse: 74 bpm | Temp: 98.4°F',
                      medicines: [
                        'Multivitamin Tabs (0-1-0)',
                        'Probiotics (1-0-0)',
                      ],
                      notes: 'No abdominal tenderness or swelling. Cleared for light sports.',
                    ),
                    const SizedBox(height: 16),
                    _buildVisitTimelineCard(
                      date: '18 Jan 2026',
                      doctor: 'Dr. Ananya Sen (Internal Medicine)',
                      reason: 'Acute Fever & Cough',
                      diagnosis: 'Upper Respiratory Tract Infection (URTI)',
                      vitals: 'BP: 130/85 mmHg | Temp: 100.2°F | SpO2: 98%',
                      medicines: [
                        'Amoxicillin 500mg (1-0-1)',
                        'Paracetamol 650mg (1-1-1)',
                      ],
                      notes: 'Responded well to 5-day antibiotic course. Cough completely resolved.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitTimelineCard({
    required String date,
    required String doctor,
    required String reason,
    required String diagnosis,
    required String vitals,
    required List<String> medicines,
    required String notes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medical_information_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diagnosis: $diagnosis',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.headingText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart_outlined,
                      size: 15,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vitals,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                const Text(
                  'Medicines Prescribed:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: medicines.map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        m,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                Text(
                  'Clinical Notes: $notes',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Future Appointment Scheduling Modal Sheet with Calendar & Quick Day Presets
  void _scheduleFutureAppointment(BuildContext context) {
    DateTime selectedDate =
        _scheduledFollowUpDate ?? DateTime.now().add(const Duration(days: 7));
    String timeSlot = _scheduledTimeSlot ?? '10:30 AM';
    final notesController = TextEditingController(
      text: _scheduledFollowUpNotes ?? 'Routine Follow-up & Evaluation',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule Future Appointment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.headingText,
                              ),
                            ),
                            Text(
                              'Patient: ${widget.appointment.patientName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 14),

                    const Text(
                      'Select After How Many Days:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPresetDayChip(
                          3,
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                        ),
                        _buildPresetDayChip(
                          7,
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                        ),
                        _buildPresetDayChip(
                          14,
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                        ),
                        _buildPresetDayChip(
                          30,
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate.isBefore(DateTime.now())
                              ? DateTime.now().add(const Duration(days: 1))
                              : selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
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
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: Text(
                        'Choose Specific Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Select Preferred Time Slot:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            '09:30 AM',
                            '10:30 AM',
                            '12:00 PM',
                            '04:30 PM',
                            '06:00 PM',
                          ].map((slot) {
                            final isSelected = timeSlot == slot;
                            return ChoiceChip(
                              label: Text(slot),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.headingText,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() => timeSlot = slot);
                                }
                              },
                            );
                          }).toList(),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Follow-up Purpose / Clinical Instructions',
                        hintText: 'e.g. Suture removal, BP & HbA1c review...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _scheduledFollowUpDate = selectedDate;
                            _scheduledTimeSlot = timeSlot;
                            _scheduledFollowUpNotes = notesController.text;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Follow-up appointment scheduled for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} at $timeSlot!',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'CONFIRM FOLLOW-UP APPOINTMENT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetDayChip(
    int days,
    DateTime currentSelected,
    Function(DateTime) onSelect,
  ) {
    final targetDate = DateTime.now().add(Duration(days: days));
    final isSelected =
        currentSelected.year == targetDate.year &&
        currentSelected.month == targetDate.month &&
        currentSelected.day == targetDate.day;

    return ActionChip(
      label: Text('After $days Days (${targetDate.day}/${targetDate.month})'),
      backgroundColor: isSelected ? AppColors.primary : AppColors.primaryLight,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.primaryDark,
        fontWeight: FontWeight.bold,
        fontSize: 11.5,
      ),
      onPressed: () => onSelect(targetDate),
    );
  }

  /// Inter-Hospital & Specialist Referral Modal Sheet
  void _showReferralModalSheet(BuildContext context) {
    String selectedHospital =
        _referralHospital ?? 'AIIMS New Delhi (Main Campus)';
    String selectedDept = _referralDepartment ?? 'Cardiology';
    String urgency = _referralUrgency ?? 'Routine Referral';
    DateTime referralDate =
        _referralDate ?? DateTime.now().add(const Duration(days: 1));
    String timeSlot = _referralTimeSlot ?? '10:00 AM';
    final notesCtrl = TextEditingController();

    final List<String> hospitals = [
      'AIIMS New Delhi (Main Campus)',
      'Ashwini Rural Health Center - Sector 4',
      'Fortis Multi-Specialty Hospital',
      'Max Super Specialty Hospital',
      'Safdarjung Hospital',
    ];

    final Map<String, String> deptDoctorMap = {
      'Cardiology': 'Dr. Ananya Sen (Sr. Cardiologist)',
      'Neurosurgery': 'Dr. Vikramaditya (HOD Neurosurgery)',
      'Orthopedics': 'Dr. Suresh Nair (Sr. Orthopedic Surgeon)',
      'Oncology': 'Dr. Meenakshi Sundaram (Consultant Oncologist)',
      'General Surgery': 'Dr. Rajesh V. Sharma (Chief Surgeon)',
      'Nephrology': 'Dr. Priya Deshmukh (Sr. Nephrologist)',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final availableDoctor =
                deptDoctorMap[selectedDept] ?? 'Dr. Available Specialist';

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_hospital_outlined,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Refer to Another Hospital / Doctor',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.headingText,
                                ),
                              ),
                              Text(
                                'Patient: ${widget.appointment.patientName}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Target Hospital Selection
                    const Text(
                      'Target Hospital / Medical Center:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHospital,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: hospitals
                          .map(
                            (h) => DropdownMenuItem(
                              value: h,
                              child: Text(
                                h,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedHospital = val);
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // Target Specialty / Department
                    const Text(
                      'Target Department / Specialist Field:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: deptDoctorMap.keys
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(
                                d,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedDept = val);
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // Auto-matched Doctor Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_pin_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Auto-Matched Specialist',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  availableDoctor,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Duty Shift: Available & On Duty Today',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.successText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Referral Urgency Level
                    const Text(
                      'Referral Urgency Level:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headingText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: urgency,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items:
                          [
                                'Routine Referral',
                                'Urgent (Within 24 Hours)',
                                'Emergency Transfer (Stat)',
                              ]
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    u,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => urgency = val);
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // Referral Date & Slot Selection
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: referralDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 90),
                                ),
                              );
                              if (picked != null) {
                                setModalState(() => referralDate = picked);
                              }
                            },
                            icon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Date: ${referralDate.day}/${referralDate.month}/${referralDate.year}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: timeSlot,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items:
                                [
                                      '09:30 AM',
                                      '10:00 AM',
                                      '11:30 AM',
                                      '02:30 PM',
                                      '04:00 PM',
                                    ]
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => timeSlot = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Clinical Reason / Summary Notes
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Clinical Notes / Reason for Referral',
                        hintText: 'e.g. Advanced cardiac evaluation required, persistent ECG changes...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final refNum =
                              'REF-${(8000 + (referralDate.day * 13) % 1999)}';
                          setState(() {
                            _referralHospital = selectedHospital;
                            _referralDepartment = selectedDept;
                            _referralDoctor = availableDoctor;
                            _referralAppointmentNo = refNum;
                            _referralUrgency = urgency;
                            _referralDate = referralDate;
                            _referralTimeSlot = timeSlot;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Referral appointment $refNum automatically scheduled at $selectedHospital under $availableDoctor!',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'SCHEDULE REFERENCE APPOINTMENT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
