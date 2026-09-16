import '../models/visit_record.dart';

/// Abstract Visit Repository interface.
abstract class VisitRepository {
  Future<List<VisitRecord>> getLastFiveVisits(String patientRef);
  Future<VisitRecord?> getVisitById(String visitId);
  Future<void> addVisit(VisitRecord newVisit);
}

/// In-memory Local Visit Repository maintaining the FIFO 5-visit rotation.
class LocalVisitRepository implements VisitRepository {
  static final LocalVisitRepository instance = LocalVisitRepository._internal();
  LocalVisitRepository._internal() {
    _resetDemoVisits();
  }

  final List<VisitRecord> _visits = [];

  void _resetDemoVisits() {
    _visits.clear();
    _visits.addAll([
      // Visit 1 (Small): Basic consultation, 1 diagnosis, 1 medicine
      const VisitRecord(
        visitId: 'V1001',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-8821',
        doctorName: 'Dr. Rajesh Verma',
        facilityRef: 'FAC-01',
        facilityName: 'Max Super Specialty Hospital',
        timestamp: '2026-09-05T10:30:00Z',
        chiefComplaints: ['Mild dry cough', 'Sore throat'],
        symptoms: ['Cough for 2 days', 'Low grade throat tickle'],
        diagnosis: [
          DiagnosisItem(code: 'J02.9', name: 'Acute Pharyngitis'),
        ],
        vitals: {
          'temperature': 37.1,
          'pulse': 76,
          'blood_pressure': '120/80',
          'spo2': 99,
        },
        medications: [
          MedicationItem(
            name: 'Cetirizine',
            strength: '10mg',
            dose: '1 tablet',
            frequency: '0-0-1',
            duration: 5,
            durationUnit: 'days',
            instructions: 'Before bedtime',
          ),
          MedicationItem(
            name: 'Paracetamol',
            strength: '500mg',
            dose: '1 tablet',
            frequency: '1-0-1',
            duration: 3,
            durationUnit: 'days',
            instructions: 'Post meals if feverish',
          ),
        ],
        advice: ['Warm water gargles with salt 3x daily', 'Hydrate well'],
        followUp: FollowUpInfo(required: false),
        notes: 'Mild upper airway viral irritation. No antibiotic required.',
      ),

      // Visit 2 (Medium): Multiple symptoms, vitals, multiple medicines
      const VisitRecord(
        visitId: 'V1002',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-4102',
        doctorName: 'Dr. Ananya Sharma',
        facilityRef: 'FAC-02',
        facilityName: 'Apollo Health City, New Delhi',
        timestamp: '2026-08-22T14:15:00Z',
        chiefComplaints: ['Occasional morning headache', 'Exertional fatigue'],
        symptoms: ['Tension type occipital tightness', 'Fatigue in afternoons'],
        diagnosis: [
          DiagnosisItem(code: 'I10', name: 'Essential Hypertension (Stage 1)'),
        ],
        vitals: {
          'temperature': 36.8,
          'pulse': 82,
          'blood_pressure': '138/88',
          'weight': 74.5,
          'spo2': 98,
        },
        medications: [
          MedicationItem(
            name: 'Telmisartan',
            strength: '40mg',
            dose: '1 tablet',
            frequency: '1-0-0',
            duration: 30,
            durationUnit: 'days',
            instructions: 'Morning empty stomach or with breakfast',
          ),
          MedicationItem(
            name: 'Amlodipine',
            strength: '2.5mg',
            dose: '1 tablet',
            frequency: '0-0-1',
            duration: 30,
            durationUnit: 'days',
            instructions: 'At bedtime',
          ),
        ],
        labTests: ['Serum Creatinine', 'Lipid Profile', 'ECG 12-Lead'],
        advice: [
          'Reduce dietary sodium intake to < 3g/day',
          'Daily brisk walking for 35 minutes',
          'Maintain regular home BP log',
        ],
        followUp: FollowUpInfo(required: true, date: '2026-09-22'),
        notes: 'BP mildly elevated on repeat check. Initiated low-dose ARB + CCB.',
      ),

      // Visit 3 (Larger): Multiple diagnoses, multiple medications, lab tests, doctor notes
      const VisitRecord(
        visitId: 'V1003',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-1904',
        doctorName: 'Dr. Kavita Rao',
        facilityRef: 'FAC-03',
        facilityName: 'City Diabetes & Hormone Centre',
        timestamp: '2026-08-10T09:30:00Z',
        chiefComplaints: ['Routine metabolic quarterly review', 'Mild polydipsia'],
        symptoms: ['Thirst after meals', 'No nocturia reported'],
        diagnosis: [
          DiagnosisItem(code: 'E11.9', name: 'Type 2 Diabetes Mellitus without complications'),
          DiagnosisItem(code: 'E78.0', name: 'Pure Hypercholesterolemia'),
        ],
        vitals: {
          'temperature': 36.6,
          'pulse': 78,
          'blood_pressure': '124/80',
          'weight': 73.8,
          'hba1c': '6.4%',
          'fasting_glucose': 112,
        },
        medications: [
          MedicationItem(
            name: 'Metformin SR',
            strength: '500mg',
            dose: '1 tablet',
            frequency: '0-0-1',
            duration: 90,
            durationUnit: 'days',
            instructions: 'Immediately post dinner',
          ),
          MedicationItem(
            name: 'Atorvastatin',
            strength: '10mg',
            dose: '1 tablet',
            frequency: '0-0-1',
            duration: 90,
            durationUnit: 'days',
            instructions: 'At bedtime',
          ),
        ],
        labTests: ['HbA1c', 'Lipid Panel', 'Urine Albumin Creatinine Ratio (UACR)'],
        procedures: ['Dilated Diabetic Retinopathy Eye Screening'],
        allergies: ['Penicillin (Mild urticaria rash)'],
        advice: [
          'Continue strict low glycemic index diet',
          'Avoid refined sugar and white flour',
          'Annual ophthalmology fundus screening scheduled',
        ],
        followUp: FollowUpInfo(required: true, date: '2026-11-10'),
        notes: 'Glycemic control is satisfactory. HbA1c stable at 6.4%. Renal markers normal.',
      ),

      // Visit 4 (Large): Dermatology & Allergy structured fields
      const VisitRecord(
        visitId: 'V1004',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-5519',
        doctorName: 'Dr. Priya Nair',
        facilityRef: 'FAC-04',
        facilityName: 'Skin & Allergy Care Centre',
        timestamp: '2026-07-28T16:00:00Z',
        chiefComplaints: ['Intense pruritic erythematous rash on bilateral forearms'],
        symptoms: ['Papular eruptions with scaling', 'Exacerbated after lawn gardening'],
        diagnosis: [
          DiagnosisItem(code: 'L23.7', name: 'Allergic Contact Dermatitis (Plant allergen)'),
        ],
        vitals: {
          'temperature': 36.7,
          'pulse': 74,
          'blood_pressure': '122/78',
        },
        medications: [
          MedicationItem(
            name: 'Mometasone Furoate 0.1% Cream',
            strength: '0.1% w/w',
            dose: 'Thin layer application',
            frequency: '1-0-1',
            duration: 7,
            durationUnit: 'days',
            route: 'topical',
            instructions: 'Apply sparingly to affected areas only',
          ),
          MedicationItem(
            name: 'Fexofenadine',
            strength: '120mg',
            dose: '1 tablet',
            frequency: '1-0-0',
            duration: 10,
            durationUnit: 'days',
            instructions: 'Morning with water',
          ),
          MedicationItem(
            name: 'Colloidal Oatmeal Bath Lotion',
            strength: 'Standard',
            dose: 'As needed',
            frequency: '1-1-1',
            duration: 14,
            durationUnit: 'days',
            route: 'topical',
            instructions: 'Gentle moisturizer after bathing',
          ),
        ],
        advice: [
          'Wear protective cotton long gloves during yard work',
          'Avoid soaps with synthetic fragrances or parabens',
          'Do not scratch or rub lesions',
        ],
        followUp: FollowUpInfo(required: true, date: '2026-08-04'),
        notes: 'Lesions clearly demarcated contact dermatitis. No secondary bacterial infection seen.',
      ),

      // Visit 5 (Stress Test): Multi-morbidity extensive clinical consultation
      const VisitRecord(
        visitId: 'V1005',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-3320',
        doctorName: 'Dr. Arjun Mehta',
        facilityRef: 'FAC-05',
        facilityName: 'Fortis Heart & Vascular Institute',
        timestamp: '2026-07-15T11:45:00Z',
        chiefComplaints: [
          'Bilateral subpatellar knee ache upon climbing stairs',
          'Mild pedal edema at end of day',
          'Post-PTCA annual cardiac routine review',
        ],
        symptoms: [
          'Crepitus right knee joint',
          'Trace pretibial edema (1+ non-pitting)',
          'No orthopnea or PND',
        ],
        diagnosis: [
          DiagnosisItem(code: 'M17.11', name: 'Primary Osteoarthritis, Right Knee'),
          DiagnosisItem(code: 'Z95.5', name: 'Presence of Coronary Angioplasty Stent'),
          DiagnosisItem(code: 'E78.2', name: 'Mixed Dyslipidemia'),
        ],
        vitals: {
          'temperature': 36.9,
          'pulse': 72,
          'blood_pressure': '126/82',
          'weight': 75.2,
          'height': 174,
          'bmi': 24.8,
          'spo2': 98,
          'eGFR': 88,
        },
        medications: [
          MedicationItem(
            name: 'Aspirin (Ecosprin)',
            strength: '75mg',
            dose: '1 tablet',
            frequency: '0-1-0',
            duration: 90,
            durationUnit: 'days',
            instructions: 'Immediately post lunch',
          ),
          MedicationItem(
            name: 'Rosuvastatin',
            strength: '10mg',
            dose: '1 tablet',
            frequency: '0-0-1',
            duration: 90,
            durationUnit: 'days',
            instructions: 'At bedtime',
          ),
          MedicationItem(
            name: 'Paracetamol Extended Release',
            strength: '1000mg',
            dose: '1 tablet',
            frequency: '1-0-1',
            duration: 5,
            durationUnit: 'days',
            instructions: 'Only during acute knee ache episodes',
          ),
          MedicationItem(
            name: 'Glucosamine Sulfate + Chondroitin',
            strength: '500/400mg',
            dose: '1 capsule',
            frequency: '1-0-1',
            duration: 60,
            durationUnit: 'days',
            instructions: 'With meals',
          ),
          MedicationItem(
            name: 'Diclofenac Sodium Gel 1%',
            strength: '1% w/w',
            dose: 'Local application',
            frequency: '1-1-1',
            duration: 14,
            durationUnit: 'days',
            route: 'topical',
            instructions: 'Gently massage onto knee joint',
          ),
        ],
        labTests: [
          'High-Sensitivity Troponin I',
          'Echocardiogram 2D (LVEF 60%)',
          'Serum Uric Acid',
          'X-Ray Bilateral Knees AP/Lateral Standing',
        ],
        procedures: ['Bilateral Knee Joint Range of Motion Assessment'],
        advice: [
          'Isometric quadriceps strengthening exercises',
          'Avoid deep squatting and cross-legged sitting',
          'Low sodium, heart-healthy Mediterranean diet',
          'Wear supportive athletic footwear with cushioned soles',
        ],
        followUp: FollowUpInfo(
          required: true,
          date: '2026-10-15',
          instructions: 'Repeat lipid profile and review knee symptoms',
        ),
        notes:
            'Echocardiography shows normal LV systolic function with EF 60%. Coronary stent is patent. Mild degenerative osteoarthritis right knee.',
      ),
    ]);
  }

  @override
  Future<List<VisitRecord>> getLastFiveVisits(String patientRef) async {
    return List.unmodifiable(_visits);
  }

  @override
  Future<VisitRecord?> getVisitById(String visitId) async {
    try {
      return _visits.firstWhere((v) => v.visitId == visitId);
    } catch (_) {
      return null;
    }
  }

  /// FIFO 5-visit rotation:
  /// Adds [newVisit] to Slot 1, shifts remaining visits, removes Visit 5.
  @override
  Future<void> addVisit(VisitRecord newVisit) async {
    _visits.insert(0, newVisit);
    if (_visits.length > 5) {
      _visits.removeRange(5, _visits.length);
    }
  }

  /// Generates an oversized visit to test QR capacity limits (Section 55).
  static VisitRecord createOversizedVisit() {
    final longList = List.generate(
      150,
      (i) => MedicationItem(
        name: 'Oversized Medication $i with extremely detailed description and extended clinical indications',
        strength: '1000mg extended release depot formula',
        dose: '2 tablets four times a day under observation',
        frequency: '1-1-1-1',
        duration: 365,
        instructions: 'Take strictly with 500ml water before breakfast, lunch, tea, and dinner',
      ),
    );

    return VisitRecord(
      visitId: 'V-STRESS-OVERSIZED',
      patientRef: 'P-7A92F81C',
      doctorRef: 'DOC-TEST',
      doctorName: 'Dr. Test Capacity',
      facilityRef: 'FAC-TEST',
      facilityName: 'Capacity Testing Facility',
      timestamp: DateTime.now().toIso8601String(),
      chiefComplaints: List.generate(100, (i) => 'Stress testing complaint $i exceeding single QR buffer with distinct token $i'),
      medications: longList,
      notes: List.generate(500, (i) => 'Clinical diagnostic parameter entry #$i with hash ${i.hashCode ^ 0xDEADBEEF}: distinct narrative description for record validation.').join('\n'),
    );
  }
}
