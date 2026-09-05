import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import 'doctor_call_screen.dart';

class DoctorConsentScreen extends StatefulWidget {
  const DoctorConsentScreen({
    required this.appointment,
    required this.repository,
    required this.firestore,
    super.key,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;

  @override
  State<DoctorConsentScreen> createState() => _DoctorConsentScreenState();
}

class _DoctorConsentScreenState extends State<DoctorConsentScreen> {
  bool _consented = false;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    await widget.repository.recordConsent(
      ConsentRecord(
        appointmentId: widget.appointment.id,
        confirmedAt: DateTime.now(),
        isDoctor: true,
      ),
    );
    await widget.repository.updateAppointmentStatus(
      widget.appointment.id,
      AppointmentStatus.inCall,
    );
    if (!mounted) return;
    setState(() => _starting = false);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DoctorCallScreen(
          appointment: widget.appointment,
          repository: widget.repository,
          firestore: widget.firestore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Before the consultation')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.appointment.patientName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.appointment.patientAge} years · ${widget.appointment.id}',
                ),
                const Divider(height: 32),
                const Text(
                  'Chief complaint',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(widget.appointment.chiefComplaint),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.all(12),
            controlAffinity: ListTileControlAffinity.leading,
            value: _consented,
            onChanged: (value) => setState(() => _consented = value ?? false),
            title: const Text(
              "I confirm I am the assigned practitioner and consent to conducting and logging this teleconsultation, including AI-based heart rate estimation from the patient's video.",
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.monitor_heart_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI-assisted vitals estimation is a screening aid only. It is not a diagnostic measurement or a substitute for clinical assessment.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: !_consented || _starting ? null : _start,
          icon: const Icon(Icons.videocam_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Start consultation'),
          ),
        ),
      ],
    ),
  );
}
