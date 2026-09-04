import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/appointment.dart';
import '../models/consent_record.dart';
import '../services/jitsi_call_service.dart';

class PreCallScreen extends StatefulWidget {
  final Appointment appointment;
  final AppointmentRepository repository;
  final String doctorName;

  const PreCallScreen({
    super.key,
    required this.appointment,
    required this.repository,
    required this.doctorName,
  });

  @override
  State<PreCallScreen> createState() => _PreCallScreenState();
}

class _PreCallScreenState extends State<PreCallScreen> {
  bool _hasConsent = false;
  bool _isStarting = false;

  Future<void> _startConsultation() async {
    if (!_hasConsent || _isStarting) return;
    setState(() => _isStarting = true);

    try {
      await widget.repository.recordConsent(
        ConsentRecord(
          appointmentId: widget.appointment.id,
          doctorConfirmedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      await startCall(
        context: context,
        appointment: widget.appointment,
        repository: widget.repository,
        doctorName: widget.doctorName,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start consultation: $error')),
      );
      setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Patient summary')),
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
                      appointment.patientName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _SummaryLine(
                      label: 'Age',
                      value: '${appointment.patientAge} years',
                    ),
                    _SummaryLine(
                      label: 'Scheduled time',
                      value: _formatTime(appointment.scheduledTime),
                    ),
                    _SummaryLine(
                      label: 'Chief complaint',
                      value: appointment.chiefComplaint,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: CheckboxListTile(
                key: const ValueKey('consent_checkbox'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                value: _hasConsent,
                onChanged: _isStarting
                    ? null
                    : (value) => setState(() => _hasConsent = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I confirm I am the assigned practitioner and consent to '
                  'conducting and logging this teleconsultation.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                key: const ValueKey('start_consultation'),
                onPressed: _hasConsent && !_isStarting
                    ? _startConsultation
                    : null,
                icon: _isStarting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_call_outlined),
                label: Text(_isStarting ? 'Starting…' : 'Start consultation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

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
