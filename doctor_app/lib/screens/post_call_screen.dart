import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/appointment.dart';
import '../models/call_log.dart';
import '../models/consultation_note.dart';

class PostCallScreen extends StatefulWidget {
  final Appointment appointment;
  final CallLog callLog;
  final AppointmentRepository repository;

  const PostCallScreen({
    super.key,
    required this.appointment,
    required this.callLog,
    required this.repository,
  });

  @override
  State<PostCallScreen> createState() => _PostCallScreenState();
}

class _PostCallScreenState extends State<PostCallScreen> {
  final _notesController = TextEditingController();
  final _referralReasonController = TextEditingController();
  final _referralFacilityController = TextEditingController();
  final List<_PrescriptionControllers> _prescriptions = [
    _PrescriptionControllers(),
  ];
  bool _referralNeeded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _referralReasonController.dispose();
    _referralFacilityController.dispose();
    for (final prescription in _prescriptions) {
      prescription.dispose();
    }
    super.dispose();
  }

  void _addPrescription() {
    setState(() => _prescriptions.add(_PrescriptionControllers()));
  }

  void _removePrescription(int index) {
    if (_prescriptions.length == 1) return;
    final removed = _prescriptions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final note = ConsultationNote(
      appointmentId: widget.appointment.id,
      notes: _notesController.text.trim(),
      prescriptionItems: _prescriptions
          .map(
            (row) => PrescriptionItem(
              drugName: row.drugName.text.trim(),
              dosage: row.dosage.text.trim(),
              duration: row.duration.text.trim(),
            ),
          )
          .toList(),
      referralNeeded: _referralNeeded,
      referralReason: _referralNeeded
          ? _referralReasonController.text.trim()
          : null,
      referralFacility: _referralNeeded
          ? _referralFacilityController.text.trim()
          : null,
    );

    try {
      await widget.repository.saveConsultationNote(note);
      await widget.repository.updateAppointmentStatus(
        widget.appointment.id,
        AppointmentStatus.completed,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save consultation: $error')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Consultation notes')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Call duration'),
                  subtitle: Text(_formatDuration(widget.callLog.duration)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Clinical notes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('clinical_notes'),
                controller: _notesController,
                minLines: 4,
                maxLines: 7,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Assessment, observations and advice',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prescription',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('add_prescription'),
                    onPressed: _addPrescription,
                    icon: const Icon(Icons.add),
                    label: const Text('Add row'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < _prescriptions.length; index++) ...[
                _PrescriptionRow(
                  index: index,
                  controllers: _prescriptions[index],
                  canDelete: _prescriptions.length > 1,
                  onDelete: () => _removePrescription(index),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Card(
                child: SwitchListTile(
                  key: const ValueKey('referral_toggle'),
                  value: _referralNeeded,
                  onChanged: (value) => setState(() => _referralNeeded = value),
                  title: const Text('Referral needed'),
                  secondary: const Icon(Icons.local_hospital_outlined),
                ),
              ),
              if (_referralNeeded) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('referral_reason'),
                  controller: _referralReasonController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Referral reason',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('referral_facility'),
                  controller: _referralFacilityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Target facility',
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('save_consultation'),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final int index;
  final _PrescriptionControllers controllers;
  final bool canDelete;
  final VoidCallback onDelete;

  const _PrescriptionRow({
    required this.index,
    required this.controllers,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text('Medicine ${index + 1}')),
                IconButton(
                  key: ValueKey('delete_prescription_$index'),
                  tooltip: 'Delete row',
                  onPressed: canDelete ? onDelete : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              key: ValueKey('drug_name_$index'),
              controller: controllers.drugName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Drug name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('dosage_$index'),
                    controller: controllers.dosage,
                    decoration: const InputDecoration(labelText: 'Dosage'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: ValueKey('duration_$index'),
                    controller: controllers.duration,
                    decoration: const InputDecoration(labelText: 'Duration'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionControllers {
  final drugName = TextEditingController();
  final dosage = TextEditingController();
  final duration = TextEditingController();

  void dispose() {
    drugName.dispose();
    dosage.dispose();
    duration.dispose();
  }
}

String _formatDuration(Duration? duration) {
  if (duration == null) return 'Not available';
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final minutes = safeDuration.inMinutes;
  final seconds = safeDuration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
