import 'package:flutter/material.dart';

import '../models/patient_appointment.dart';
import '../models/patient_call_log.dart';

class PatientCallEndedScreen extends StatelessWidget {
  final PatientAppointment appointment;
  final PatientCallLog callLog;

  const PatientCallEndedScreen({
    super.key,
    required this.appointment,
    required this.callLog,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Consultation complete'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                callLog.hadError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 72,
                color: callLog.hadError
                    ? Theme.of(context).colorScheme.error
                    : const Color(0xFF236C2E),
              ),
              const SizedBox(height: 20),
              Text(
                callLog.hadError
                    ? 'The call ended unexpectedly'
                    : 'Your consultation has ended',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                appointment.doctorName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Call duration'),
                  subtitle: Text(_formatDuration(callLog.duration)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const ValueKey('done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration? duration) {
  if (duration == null) return 'Not available';
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final minutes = safeDuration.inMinutes;
  final seconds = safeDuration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
