import 'dart:convert';
import 'dart:io';
import '../models/visit_record.dart';

class LocalVisitRepository {
  LocalVisitRepository._();
  static final LocalVisitRepository instance = LocalVisitRepository._();

  final List<VisitRecord> _dynamicVisits = [];

  static final List<VisitRecord> demoVisits = [
    VisitRecord(
      visitId: 'V1001',
      patientRef: 'P-7A92F81C',
      doctorName: 'Dr. Anjali Sharma',
      facilityName: 'City Care Hospital',
      timestamp: '2026-09-10T10:30:00Z',
      chiefComplaints: ['High fever for 3 days', 'Severe dry cough', 'Sore throat'],
      symptoms: ['Body ache', 'Mild fatigue', 'Loss of appetite'],
      diagnosis: [
        DiagnosisItem(code: 'J06.9', name: 'Acute Upper Respiratory Infection'),
      ],
      vitals: {
        'blood_pressure': '120/80 mmHg',
        'pulse': '84 bpm',
        'temperature': '101.2 °F',
        'spo2': '98%',
      },
      medications: [
        MedicationItem(
          name: 'Paracetamol',
          strength: '650mg',
          dose: '1 tablet',
          frequency: 'TDS (3 times/day)',
          duration: '5',
          durationUnit: 'days',
          instructions: 'After meals with water',
        ),
        MedicationItem(
          name: 'Azithromycin',
          strength: '500mg',
          dose: '1 tablet',
          frequency: 'OD (Once daily)',
          duration: '3',
          durationUnit: 'days',
          instructions: '1 hour before food',
        ),
      ],
      labTests: ['Complete Blood Count (CBC)'],
      allergies: ['Penicillin'],
      advice: ['Hydrate well (minimum 3L/day)', 'Complete antibiotic course', 'Steam inhalation twice daily'],
      followUp: FollowUpInfo(required: true, date: '2026-09-15'),
      notes: 'Patient responded well to initial examination. Chest clear, no wheezing.',
    ),
    VisitRecord(
      visitId: 'V1002',
      patientRef: 'P-7A92F81C',
      doctorName: 'Dr. Rajesh Verma',
      facilityName: 'Apex Heart & Health Clinic',
      timestamp: '2026-08-22T14:15:00Z',
      chiefComplaints: ['Routine Hypertension Follow-up', 'Mild occipital headache'],
      symptoms: ['Morning dizziness', 'Mild ankle swelling'],
      diagnosis: [
        DiagnosisItem(code: 'I10', name: 'Essential (Primary) Hypertension'),
      ],
      vitals: {
        'blood_pressure': '138/88 mmHg',
        'pulse': '76 bpm',
        'weight': '78 kg',
        'bmi': '25.8',
      },
      medications: [
        MedicationItem(
          name: 'Telmisartan',
          strength: '40mg',
          dose: '1 tablet',
          frequency: 'OD (Morning)',
          duration: '30',
          durationUnit: 'days',
          instructions: 'Daily morning at 8 AM',
        ),
        MedicationItem(
          name: 'Amlodipine',
          strength: '5mg',
          dose: '1 tablet',
          frequency: 'OD (Night)',
          duration: '30',
          durationUnit: 'days',
          instructions: 'Before bedtime',
        ),
      ],
      labTests: ['Serum Creatinine', 'Lipid Profile', 'ECG'],
      allergies: ['Penicillin'],
      advice: ['Low salt diet (< 5g/day)', 'Daily 30 min brisk walk', 'Avoid stress and caffeine'],
      followUp: FollowUpInfo(required: true, date: '2026-09-22'),
      notes: 'Blood pressure slightly elevated compared to target 125/80. Titrated amlodipine.',
    ),
    VisitRecord(
      visitId: 'V1003',
      patientRef: 'P-7A92F81C',
      doctorName: 'Dr. Sunita Rao',
      facilityName: 'Metro Diabetes Care',
      timestamp: '2026-07-15T11:00:00Z',
      chiefComplaints: ['Quarterly Glycemic Review', 'Occasional afternoon fatigue'],
      symptoms: ['Mild polyuria', 'Dry mouth'],
      diagnosis: [
        DiagnosisItem(code: 'E11.9', name: 'Type 2 Diabetes Mellitus'),
      ],
      vitals: {
        'blood_pressure': '124/82 mmHg',
        'pulse': '72 bpm',
        'fasting_glucose': '126 mg/dL',
        'postprandial_glucose': '164 mg/dL',
        'hba1c': '6.9%',
      },
      medications: [
        MedicationItem(
          name: 'Metformin',
          strength: '500mg',
          dose: '1 tablet',
          frequency: 'BD (Twice daily)',
          duration: '60',
          durationUnit: 'days',
          instructions: 'With breakfast and dinner',
        ),
        MedicationItem(
          name: 'Glimepiride',
          strength: '1mg',
          dose: '1 tablet',
          frequency: 'OD (Morning)',
          duration: '60',
          durationUnit: 'days',
          instructions: '15 mins before breakfast',
        ),
      ],
      labTests: ['HbA1c test', 'Urine Microalbumin'],
      allergies: ['Penicillin'],
      advice: ['Strict diabetic diet', 'Avoid sugary beverages and refined carbs', 'Monitor foot hygiene'],
      followUp: FollowUpInfo(required: true, date: '2026-10-15'),
      notes: 'HbA1c stable at 6.9%. Good compliance with dietary modifications.',
    ),
    VisitRecord(
      visitId: 'V1004',
      patientRef: 'P-7A92F81C',
      doctorName: 'Dr. Manoj Kapoor',
      facilityName: 'Pulmonary Care Institute',
      timestamp: '2026-06-04T09:45:00Z',
      chiefComplaints: ['Wheezing on exertion', 'Seasonal nocturnal cough'],
      symptoms: ['Chest tightness', 'Shortness of breath on climbing stairs'],
      diagnosis: [
        DiagnosisItem(code: 'J45.909', name: 'Bronchial Asthma (Mild Persistent)'),
      ],
      vitals: {
        'blood_pressure': '118/76 mmHg',
        'pulse': '88 bpm',
        'spo2': '96%',
        'pefr': '380 L/min',
      },
      medications: [
        MedicationItem(
          name: 'Budesonide + Formoterol Inhaler',
          strength: '200/6mcg',
          dose: '2 puffs',
          frequency: 'BD (Morning & Night)',
          duration: '30',
          durationUnit: 'days',
          instructions: 'Rinse mouth with water after inhalation',
        ),
        MedicationItem(
          name: 'Montelukast',
          strength: '10mg',
          dose: '1 tablet',
          frequency: 'OD (Night)',
          duration: '30',
          durationUnit: 'days',
          instructions: 'At bedtime',
        ),
      ],
      labTests: ['Spirometry / PFT', 'Serum IgE Level'],
      allergies: ['Penicillin', 'Dust mites'],
      advice: ['Avoid dust and pollen exposure', 'Keep emergency inhaler handy', 'Use spacer with inhaler'],
      followUp: FollowUpInfo(required: true, date: '2026-07-04'),
      notes: 'Bilateral expiratory rhonchi heard. Significant improvement post bronchodilator challenge.',
    ),
    VisitRecord(
      visitId: 'V1005',
      patientRef: 'P-7A92F81C',
      doctorName: 'Dr. Priya Nair',
      facilityName: 'Gastro Care Centre',
      timestamp: '2026-04-18T16:20:00Z',
      chiefComplaints: ['Crampy abdominal pain', 'Watery diarrhea x 4 episodes', 'Nausea'],
      symptoms: ['Mild dehydration', 'Low-grade fever', 'Weakness'],
      diagnosis: [
        DiagnosisItem(code: 'A09', name: 'Infectious Gastroenteritis'),
      ],
      vitals: {
        'blood_pressure': '110/70 mmHg',
        'pulse': '92 bpm',
        'temperature': '99.4 °F',
        'spo2': '99%',
      },
      medications: [
        MedicationItem(
          name: 'Oral Rehydration Salts (ORS)',
          strength: 'Standard WHO Sachet',
          dose: '1 liter solution',
          frequency: 'Frequent sips',
          duration: '3',
          durationUnit: 'days',
          instructions: 'Drink after each loose stool',
        ),
        MedicationItem(
          name: 'Ondansetron',
          strength: '4mg',
          dose: '1 tablet',
          frequency: 'SOS (When needed)',
          duration: '3',
          durationUnit: 'days',
          instructions: 'For nausea/vomiting',
        ),
        MedicationItem(
          name: 'Probiotics (Bacillus clausii)',
          strength: '2 billion spores',
          dose: '1 mini bottle',
          frequency: 'BD (Twice daily)',
          duration: '5',
          durationUnit: 'days',
          instructions: 'Oral suspension after food',
        ),
      ],
      labTests: ['Stool Routine & Microscopy', 'Serum Electrolytes'],
      allergies: ['Penicillin'],
      advice: ['BRAT diet (banana, rice, applesauce, toast)', 'Strictly boiled/filtered water', 'No dairy or spicy foods'],
      followUp: FollowUpInfo(required: false, date: 'SOS if dehydration worsens'),
      notes: 'Abdomen soft, diffuse mild tenderness in umbilical region. No guarding or rigidity.',
    ),
  ];

  /// Sets or updates the active in-memory visits list (e.g. from backend database or JSON file)
  void setVisits(List<VisitRecord> visits) {
    if (visits.isNotEmpty) {
      _dynamicVisits.clear();
      _dynamicVisits.addAll(visits);
    }
  }

  /// Saves the current visits list to a local JSON file on device storage
  Future<void> saveVisitsToJsonFile(List<VisitRecord> visits, String filePath) async {
    try {
      final file = File(filePath);
      final jsonList = visits.map((v) => v.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await file.writeAsString(jsonStr, flush: true);
    } catch (_) {}
  }

  /// Loads visits from a local JSON file on device storage
  Future<List<VisitRecord>> loadVisitsFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = decoded
              .whereType<Map>()
              .map((m) => VisitRecord.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (loaded.isNotEmpty) {
            setVisits(loaded);
            return loaded;
          }
        }
      }
    } catch (_) {}
    return _dynamicVisits.isNotEmpty ? _dynamicVisits : demoVisits;
  }

  Future<List<VisitRecord>> getLastFiveVisits(String patientRef) async {
    return _dynamicVisits.isNotEmpty ? _dynamicVisits : demoVisits;
  }

  Future<VisitRecord?> getVisitById(String visitId) async {
    final list = _dynamicVisits.isNotEmpty ? _dynamicVisits : demoVisits;
    try {
      return list.firstWhere((v) => v.visitId == visitId);
    } catch (_) {
      return null;
    }
  }
}
