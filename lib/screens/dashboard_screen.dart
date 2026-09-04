import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/appointment.dart';
import 'pre_call_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppointmentRepository repository;
  final String doctorName;

  const DashboardScreen({
    super.key,
    required this.repository,
    required this.doctorName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Appointment>> _queueFuture;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  void _loadQueue() {
    _queueFuture = widget.repository.getTodaysQueue();
  }

  Future<void> _openAppointment(Appointment appointment) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PreCallScreen(
          appointment: appointment,
          repository: widget.repository,
          doctorName: widget.doctorName,
        ),
      ),
    );
    if (!mounted) return;
    setState(_loadQueue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today’s consultations'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.doctorName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Appointment>>(
        future: _queueFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _QueueError(onRetry: () => setState(_loadQueue));
          }

          final appointments = [...?snapshot.data]
            ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));
          if (appointments.isEmpty) {
            return const Center(
              child: Text('No consultations scheduled today.'),
            );
          }
          final waiting = appointments
              .where((item) => item.status == AppointmentStatus.waiting)
              .toList();
          final nextAppointment = waiting.isEmpty ? null : waiting.first;

          return RefreshIndicator(
            onRefresh: () async {
              setState(_loadQueue);
              await _queueFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  '${appointments.length} patients in today’s queue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (final appointment in appointments) ...[
                  _AppointmentCard(
                    appointment: appointment,
                    canJoin: identical(appointment, nextAppointment),
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

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool canJoin;
  final VoidCallback onJoin;

  const _AppointmentCard({
    required this.appointment,
    required this.canJoin,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canJoin ? onJoin : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Text('${appointment.queuePosition}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scheduled ${_formatTime(appointment.scheduledTime)}',
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                appointment.chiefComplaint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: ValueKey('join_${appointment.id}'),
                  onPressed: canJoin ? onJoin : null,
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Join'),
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
  final AppointmentStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AppointmentStatus.waiting => ('Waiting', const Color(0xFF8A5A00)),
      AppointmentStatus.inCall => ('In progress', const Color(0xFF006C67)),
      AppointmentStatus.completed => ('Completed', const Color(0xFF236C2E)),
      AppointmentStatus.missed => ('Missed', const Color(0xFFBA1A1A)),
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

class _QueueError extends StatelessWidget {
  final VoidCallback onRetry;

  const _QueueError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load today’s queue.'),
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
