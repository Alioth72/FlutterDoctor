import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import 'doctor_consent_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({
    required this.repository,
    required this.firestore,
    this.firebaseError,
    super.key,
  });
  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;
  final String? firebaseError;

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  late Future<List<Appointment>> _queue;

  @override
  void initState() {
    super.initState();
    _queue = widget.repository.getTodaysQueue();
  }

  void _refresh() =>
      setState(() => _queue = widget.repository.getTodaysQueue());

  String _time(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _open(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorConsentScreen(
          appointment: appointment,
          repository: widget.repository,
          firestore: widget.firestore,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Today’s teleconsultations'),
      actions: const <Widget>[
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: CircleAvatar(child: Text('MS')),
        ),
      ],
    ),
    body: FutureBuilder<List<Appointment>>(
      future: _queue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final queue = snapshot.data!;
        final firstWaiting = queue.indexWhere(
          (item) => item.status == AppointmentStatus.waiting,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    value: '${queue.length}',
                    label: 'Scheduled',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    value:
                        '${queue.where((item) => item.status == AppointmentStatus.completed).length}',
                    label: 'Completed',
                  ),
                ),
              ],
            ),
            if (widget.firebaseError != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Call signaling needs Firebase setup. The queue demo remains available; see SETUP.md.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Queue',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < queue.length; index++) ...<Widget>[
              _AppointmentCard(
                appointment: queue[index],
                time: _time(queue[index].scheduledTime),
                canJoin: index == firstWaiting,
                onJoin: () => _open(queue[index]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.time,
    required this.canJoin,
    required this.onJoin,
  });
  final Appointment appointment;
  final String time;
  final bool canJoin;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(child: Text('${appointment.queuePosition}')),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  appointment.patientName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('${appointment.patientAge} years · $time'),
                const SizedBox(height: 8),
                Text(appointment.chiefComplaint),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: canJoin ? onJoin : null,
            child: Text(
              appointment.status == AppointmentStatus.completed
                  ? 'Done'
                  : 'Join',
            ),
          ),
        ],
      ),
    ),
  );
}
