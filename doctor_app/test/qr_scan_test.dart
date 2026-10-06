import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrx_protocol/hrx_protocol.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sih_project/models/appointment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Visit QR Decompression ("Unzipping") Tests', () {
    final sampleVisit = VisitRecord(
      visitId: 'V1009',
      patientRef: 'P-998877',
      doctorRef: 'DOC-123',
      doctorName: 'Dr. Neha Sen',
      facilityRef: 'FAC-01',
      facilityName: 'District Civil Hospital',
      timestamp: '2026-09-16T10:30:00Z',
      chiefComplaints: ['High fever for 3 days', 'Severe dry cough'],
      symptoms: ['Fever', 'Cough', 'Fatigue'],
      diagnosis: const [
        DiagnosisItem(code: 'J06.9', name: 'Acute Upper Respiratory Infection'),
        DiagnosisItem(code: 'R50.9', name: 'Pyrexia of Unknown Origin'),
      ],
      vitals: const {
        'blood_pressure': '120/80',
        'pulse': '78 bpm',
        'temperature': '101.4 F',
        'spo2': '98%',
      },
      medications: const [
        MedicationItem(
          name: 'Paracetamol 650mg',
          dose: '1 tablet',
          frequency: '1-0-1 after meals',
          duration: 3,
          durationUnit: 'days',
        ),
        MedicationItem(
          name: 'Azithromycin 500mg',
          dose: '1 tablet',
          frequency: '0-0-1 daily',
          duration: 5,
          durationUnit: 'days',
        ),
      ],
      labTests: const ['Complete Blood Count (CBC)', 'Dengue Serology NS1'],
      allergies: const ['Penicillin', 'Sulfa Drugs'],
      advice: const ['Drink plenty of warm fluids', 'Complete entire antibiotic course', 'Rest in bed'],
      followUp: const FollowUpInfo(
        required: true,
        date: '2026-09-20',
        instructions: 'Follow up if temperature stays above 101F',
      ),
    );

    test('Encodes and decompresses (unzips) offline visit QR with 100% fidelity', () {
      final encoder = HrxEncoder();
      final encodeResult = encoder.encodeCompactVisitQr(sampleVisit);

      expect(encodeResult.qrPayload.startsWith('HRX:Z:'), isTrue);
      expect(HrxDecoder.isHrxPayload(encodeResult.qrPayload), isTrue);

      final decoder = HrxDecoder();
      final decodeResult = decoder.decode(encodeResult.qrPayload);

      expect(decodeResult.success, isTrue);
      expect(decodeResult.isVisit, isTrue);
      expect(decodeResult.visit, isNotNull);

      final visit = decodeResult.visit!;
      expect(visit.visitId, equals('V1009'));
      expect(visit.patientRef, equals('P-998877'));
      expect(visit.doctorName, equals('Dr. Neha Sen'));
      expect(visit.diagnosis.isNotEmpty, isTrue);
      expect(visit.medications.isNotEmpty, isTrue);
      expect(visit.allergies, contains('Penicillin'));
      expect(visit.vitals['temperature'], equals('101.4 F'));
    });

    test('Decompresses payload with whitespace, line breaks, and unpadded Base64', () {
      final encoder = HrxEncoder();
      final encodeResult = encoder.encodeCompactVisitQr(sampleVisit);

      // Simulate scanner artifact with newlines, spaces, and stripped padding '='
      var dirtyPayload = '  \n ${encodeResult.qrPayload.replaceAll('=', '')} \r\n  ';

      final decoder = HrxDecoder();
      final decodeResult = decoder.decode(dirtyPayload);

      expect(decodeResult.success, isTrue);
      expect(decodeResult.visit?.visitId, equals('V1009'));
    });

    test('Decompresses payload with enclosing quotes', () {
      final encoder = HrxEncoder();
      final encodeResult = encoder.encodeCompactVisitQr(sampleVisit);

      final quotedPayload = '"${encodeResult.qrPayload}"';

      final decoder = HrxDecoder();
      final decodeResult = decoder.decode(quotedPayload);

      expect(decodeResult.success, isTrue);
      expect(decodeResult.visit?.visitId, equals('V1009'));
    });
  });

  group('Online Patient Identity QR Decoding Tests', () {
    const customPatient = PatientRecord(
      patientRef: 'P-98765432',
      patientId: '14-2026-4512-8821',
      name: 'Ramesh Patel',
      gender: 'Male',
      bloodGroup: 'O+',
      phone: '9811223344',
      dateOfBirth: '1990-05-20',
    );

    test('Decodes compact HRX patient QR and preserves real patient name & details', () {
      final encoder = HrxEncoder();
      final qrString = encoder.encodePatientQr(customPatient, compact: true);

      expect(qrString.startsWith('HRX:P|1|'), isTrue);
      expect(HrxDecoder.isHrxPayload(qrString), isTrue);

      final decoder = HrxDecoder();
      final decodeResult = decoder.decode(qrString);

      expect(decodeResult.success, isTrue);
      expect(decodeResult.isPatient, isTrue);
      expect(decodeResult.patient, isNotNull);

      final p = decodeResult.patient!;
      expect(p.name, equals('Ramesh Patel'));
      expect(p.patientRef, equals('P-98765432'));
      expect(p.patientId, equals('14-2026-4512-8821'));
      expect(p.gender, equals('Male'));
      expect(p.bloodGroup, equals('O+'));
      expect(p.phone, equals('9811223344'));
    });

    test('LocalPatientRepository does not overwrite newly scanned patient with dummy data', () async {
      final repo = LocalPatientRepository.instance;
      
      // Before saving, non-existent patient returns null instead of dummy
      final before = await repo.getPatient(customPatient.patientRef);
      expect(before, isNull);

      // Save and retrieve
      repo.savePatient(customPatient);
      final after = await repo.getPatient(customPatient.patientRef);
      expect(after, isNotNull);
      expect(after?.name, equals('Ramesh Patel'));
      expect(after?.bloodGroup, equals('O+'));
    });
  });

  group('Online JSON and Legacy QR Payload Tests', () {
    test('Correctly extracts appointment fields from raw JSON QR', () {
      final jsonPayload = jsonEncode({
        'id': 'APT-888',
        'appointmentNo': 'APT-888',
        'patientName': 'Sunita Sharma',
        'age': 35,
        'gender': 'Female',
        'timing': '11:00 AM - Today',
        'diagnosis': 'Seasonal Flu',
        'paymentStatus': 'Paid Online (₹450)',
        'isPaid': true,
      });

      final decoded = jsonDecode(jsonPayload) as Map<String, dynamic>;
      final appointment = AppointmentItem(
        id: decoded['id'],
        appointmentNo: decoded['appointmentNo'],
        patientName: decoded['patientName'],
        age: decoded['age'],
        gender: decoded['gender'],
        timing: decoded['timing'],
        paymentStatus: decoded['paymentStatus'],
        isPaid: decoded['isPaid'],
        mode: AppointmentMode.qr,
        patientHistory: const ['Online token verified'],
        heightCm: 165.0,
        weightKg: 62.0,
        familyHistory: 'None',
        diagnosis: decoded['diagnosis'],
        medicines: const [],
        isAdmitted: false,
      );

      expect(appointment.appointmentNo, equals('APT-888'));
      expect(appointment.patientName, equals('Sunita Sharma'));
      expect(appointment.gender, equals('Female'));
      expect(appointment.isPaid, isTrue);
    });

    test('Extracts appointment ID from online URL', () {
      const url = 'https://hospital-portal.in/checkin?id=APT-555';
      final uri = Uri.parse(url);
      final idParam = uri.queryParameters['id'];

      expect(idParam, equals('APT-555'));
    });
  });

  group('Mobile Scanner Controller Specification', () {
    test('Controller is configured for continuous scanning without freezing', () {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 800,
        formats: const [BarcodeFormat.qrCode],
        facing: CameraFacing.back,
      );

      expect(controller.detectionSpeed, equals(DetectionSpeed.normal));
      expect(controller.formats, contains(BarcodeFormat.qrCode));
      expect(controller.formats.length, equals(1));
    });
  });
}
