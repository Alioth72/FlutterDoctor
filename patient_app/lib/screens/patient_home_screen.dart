import 'package:flutter/material.dart';

import '../data/patient_appointment_repository.dart';
import '../models/patient_appointment.dart';
import 'patient_pre_call_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  final PatientAppointmentRepository repository;

  const PatientHomeScreen({super.key, required this.repository});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late Future<List<PatientAppointment>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  void _loadAppointments() {
    _appointmentsFuture = widget.repository.getTodaysAppointments();
  }

  Future<void> _openAppointment(PatientAppointment appointment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PatientPreCallScreen(
          appointment: appointment,
          repository: widget.repository,
        ),
      ),
    );
    if (!mounted) return;
    setState(_loadAppointments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My consultations')),
      body: FutureBuilder<List<PatientAppointment>>(
        future: _appointmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: () => setState(_loadAppointments));
          }

          final appointments = [...?snapshot.data]
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          if (appointments.isEmpty) {
            return const Center(
              child: Text('No consultations scheduled today.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(_loadAppointments);
              await _appointmentsFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text('Today', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                for (final appointment in appointments) ...[
                  _ConsultationCard(
                    appointment: appointment,
                    onJoin: () => _openAppointment(appointment),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final PatientAppointment appointment;
  final VoidCallback onJoin;

  const _ConsultationCard({required this.appointment, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final canJoin = appointment.status == PatientAppointmentStatus.ready;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canJoin ? onJoin : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.medical_services_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.doctorName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(appointment.doctorSpecialty),
                      ],
                    ),
                  ),
                  _StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 8),
                  Text(_formatTime(appointment.scheduledTime)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appointment.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('join_${appointment.id}'),
                  onPressed: canJoin ? onJoin : null,
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join consultation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PatientAppointmentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PatientAppointmentStatus.ready => ('Ready', const Color(0xFF365F91)),
      PatientAppointmentStatus.inCall => ('In call', const Color(0xFF006C67)),
      PatientAppointmentStatus.completed => (
        'Completed',
        const Color(0xFF236C2E),
      ),
      PatientAppointmentStatus.missed => ('Missed', const Color(0xFFBA1A1A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load your consultation.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
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
