import 'package:flutter/material.dart';

import '../data/appointment_repository.dart';
import '../models/teleconsult_models.dart';

class PostCallScreen extends StatefulWidget {
  const PostCallScreen({
    required this.appointment,
    required this.repository,
    required this.callLog,
    required this.bpmSamples,
    super.key,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  final CallLog callLog;
  final List<BpmSample> bpmSamples;

  @override
  State<PostCallScreen> createState() => _PostCallScreenState();
}

class _PostCallScreenState extends State<PostCallScreen> {
  final _notesController = TextEditingController();
  final _referralReasonController = TextEditingController();
  final _referralFacilityController = TextEditingController();
  final List<PrescriptionItem> _items = <PrescriptionItem>[PrescriptionItem()];
  bool _referralNeeded = false;
  bool _saving = false;

  String get _duration {
    final seconds = widget.callLog.duration?.inSeconds ?? 0;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final validSamples = widget.bpmSamples
        .where((sample) => sample.confidence >= 0.5)
        .toList();
    final note = ConsultationNote(
      appointmentId: widget.appointment.id,
      notes: _notesController.text.trim(),
      prescriptionItems: _items
          .where((item) => item.drugName.trim().isNotEmpty)
          .toList(),
      referralNeeded: _referralNeeded,
      referralReason: _referralReasonController.text.trim(),
      referralFacility: _referralFacilityController.text.trim(),
      bpmSampleCount: validSamples.length,
    );
    if (validSamples.isNotEmpty) {
      final values = validSamples.map((sample) => sample.bpm).toList()..sort();
      note.minBpm = values.first;
      note.maxBpm = values.last;
      note.avgBpm = values.reduce((a, b) => a + b) / values.length;
    }
    await widget.repository.saveConsultationNote(note);
    await widget.repository.updateAppointmentStatus(
      widget.appointment.id,
      AppointmentStatus.completed,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _referralReasonController.dispose();
    _referralFacilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reliableSamples = widget.bpmSamples
        .where((sample) => sample.confidence >= 0.5)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete consultation'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.check)),
              title: Text(widget.appointment.patientName),
              subtitle: Text('Call duration $_duration'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'AI-assisted vitals summary',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reliableSamples == 0
                        ? 'No reliable BPM samples recorded in this build.'
                        : '$reliableSamples reliable samples recorded.',
                  ),
                  const Text(
                    'Screening aid only; not a diagnostic measurement.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Consultation notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Prescription',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _items.add(PrescriptionItem())),
                icon: const Icon(Icons.add),
                label: const Text('Add medicine'),
              ),
            ],
          ),
          for (var index = 0; index < _items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Medicine',
                        ),
                        onChanged: (value) => _items[index].drugName = value,
                      ),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Dosage',
                              ),
                              onChanged: (value) =>
                                  _items[index].dosage = value,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                              ),
                              onChanged: (value) =>
                                  _items[index].duration = value,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _referralNeeded,
            onChanged: (value) => setState(() => _referralNeeded = value),
            title: const Text('Referral needed'),
          ),
          if (_referralNeeded) ...<Widget>[
            TextField(
              controller: _referralReasonController,
              decoration: const InputDecoration(
                labelText: 'Referral reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referralFacilityController,
              decoration: const InputDecoration(
                labelText: 'Referral facility',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? 'Saving…' : 'Save and complete'),
            ),
          ),
        ],
      ),
    );
  }
}
