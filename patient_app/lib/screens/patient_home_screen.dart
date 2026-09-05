import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';
import 'patient_call_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({
    required this.repository,
    required this.firestore,
    this.firebaseError,
    super.key,
  });

  final AppointmentRepository repository;
  final FirebaseFirestore? firestore;
  final String? firebaseError;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  bool _consented = false;
  bool _joining = false;

  String _formatTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _join(Appointment appointment) async {
    setState(() => _joining = true);
    await widget.repository.recordConsent(
      ConsentRecord(
        appointmentId: appointment.id,
        confirmedAt: DateTime.now(),
        isDoctor: false,
      ),
    );
    if (!mounted) return;
    setState(() => _joining = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientCallScreen(
          appointment: appointment,
          repository: widget.repository,
          firestore: widget.firestore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swasthya Connect'),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(child: Icon(Icons.person_outline)),
          ),
        ],
      ),
      body: FutureBuilder<Appointment>(
        future: widget.repository.getAppointment('apt_001'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final appointment = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text(
                'Your consultation',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Join from a quiet, well-lit place when you are ready.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 26,
                            child: Icon(Icons.medical_services_outlined),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Dr. Meera Sharma',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text('General Medicine · District Hospital'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _InfoRow(
                        icon: Icons.schedule,
                        label:
                            'Today at ${_formatTime(appointment.scheduledTime)}',
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.tag,
                        label: 'Appointment ${appointment.id}',
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.firebaseError != null) ...<Widget>[
                const SizedBox(height: 16),
                const _SetupNotice(),
              ],
              const SizedBox(height: 16),
              Card(
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.all(12),
                  value: _consented,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setState(() => _consented = value ?? false),
                  title: const Text(
                    'I consent to this video consultation, including AI-based '
                    'heart rate estimation from my video by my doctor during the call.',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: !_consented || _joining
                    ? null
                    : () => _join(appointment),
                icon: _joining
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.videocam_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Join call'),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'For severe chest pain, breathing difficulty, heavy bleeding, or '
                'loss of consciousness, seek emergency care immediately.',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 20),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.settings_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demo UI is available, but calls need this app’s Firebase '
              'configuration. See SETUP.md in the project root.',
            ),
          ),
        ],
      ),
    ),
  );
}
