import 'package:flutter/material.dart';

import '../data/patient_appointment_repository.dart';
import '../models/patient_appointment.dart';
import '../services/patient_jitsi_call_service.dart';

class PatientPreCallScreen extends StatefulWidget {
  final PatientAppointment appointment;
  final PatientAppointmentRepository repository;

  const PatientPreCallScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });

  @override
  State<PatientPreCallScreen> createState() => _PatientPreCallScreenState();
}

class _PatientPreCallScreenState extends State<PatientPreCallScreen> {
  bool _isJoining = false;

  Future<void> _joinConsultation() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      await startPatientCall(
        context: context,
        appointment: widget.appointment,
        repository: widget.repository,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to join consultation: $error')),
      );
      setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;

    return Scaffold(
      appBar: AppBar(title: const Text('Consultation details')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(appointment.doctorSpecialty),
                    const Divider(height: 32),
                    _DetailLine(
                      label: 'Scheduled time',
                      value: _formatTime(appointment.scheduledTime),
                    ),
                    _DetailLine(label: 'Reason', value: appointment.reason),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Before you join'),
                subtitle: Text(
                  'Find a quiet, well-lit place and make sure your camera, '
                  'microphone, and internet connection are available.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('join_call'),
                onPressed: _isJoining ? null : _joinConsultation,
                icon: _isJoining
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call_outlined),
                label: Text(_isJoining ? 'Joining…' : 'Join consultation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
