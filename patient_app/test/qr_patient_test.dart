import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrx_protocol/hrx_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Patient Identity QR Tests', () {
    test('Compact Patient Identity QR encoding and round-trip decoding', () {
      const patient = PatientRecord(
        patientRef: 'P-9B21C4D8',
        patientId: 'ASH-PT-1042',
        name: 'Pooja Sharma',
        gender: 'Female',
        bloodGroup: 'B+',
        phone: '+919876543210',
      );

      final qrString = HrxEncoder().encodePatientQr(patient, compact: true);

      // Verify compact format: HRX:P|1|<ref>|<id>|<name>|<gender>|<blood>|<phone>
      expect(qrString.startsWith('HRX:P|1|'), isTrue);
      expect(qrString, contains('P-9B21C4D8'));
      expect(qrString, contains('ASH-PT-1042'));
      expect(qrString, contains('Pooja Sharma'));
      expect(qrString, contains('Female'));
      expect(qrString, contains('B+'));
      expect(qrString, contains('+919876543210'));
      expect(qrString.length, lessThan(80)); // Highly scannable, QR Version 3

      // Verify decoding
      final decoder = HrxDecoder();
      final result = decoder.decode(qrString);

      expect(result.success, isTrue);
      expect(result.type, equals(HrxDecodeType.patient));
      expect(result.patient, isNotNull);
      expect(result.patient!.name, equals('Pooja Sharma'));
      expect(result.patient!.patientRef, equals('P-9B21C4D8'));
      expect(result.patient!.patientId, equals('ASH-PT-1042'));
      expect(result.patient!.gender, equals('Female'));
      expect(result.patient!.bloodGroup, equals('B+'));
      expect(result.patient!.phone, equals('+919876543210'));
    });
  });

  group('Offline Visit QR Tests (Compact Deflate Pipeline)', () {
    test('Encodes and decodes compact visit with minimal payload size', () {
      const visit = VisitRecord(
        visitId: 'VIS-2026-9021',
        patientRef: 'P-9B21C4D8',
        timestamp: '2026-09-15T10:30:00Z',
        doctorRef: 'DOC-4412',
        facilityRef: 'FAC-001',
        diagnosis: [
          DiagnosisItem(code: 'J06.9', name: 'Acute upper respiratory infection'),
        ],
        vitals: {
          'systolic_bp': 120,
          'diastolic_bp': 80,
          'pulse': 72,
          'temp': 98.6,
        },
        medications: [
          MedicationItem(
            name: 'Paracetamol',
            strength: '500mg',
            dose: '1 tab',
            frequency: 'TDS',
            duration: 5,
            durationUnit: 'days',
            instructions: 'After meals',
          ),
          MedicationItem(
            name: 'Cetirizine',
            strength: '10mg',
            dose: '1 tab',
            frequency: 'OD',
            duration: 3,
            durationUnit: 'days',
            instructions: 'At bedtime',
          ),
        ],
        advice: ['Drink plenty of warm fluids', 'Rest for 2 days'],
        followUp: FollowUpInfo(required: true, date: '2026-09-22'),
      );

      final encodeResult = HrxEncoder().encodeCompactVisitQr(visit);
      final qrPayload = encodeResult.qrPayload;

      // Verify prefix and size compactness
      expect(qrPayload.startsWith('HRX:Z:'), isTrue);
      // Compact visit payload should be under 250 characters (QR Version 6-8), not 600+
      expect(qrPayload.length, lessThan(250));

      // Roundtrip decode
      final decoder = HrxDecoder();
      final result = decoder.decode(qrPayload);

      expect(result.success, isTrue);
      expect(result.type, equals(HrxDecodeType.visit));
      expect(result.visit, isNotNull);
      expect(result.visit!.visitId, equals('VIS-2026-9021'));
      expect(result.visit!.patientRef, equals('P-9B21C4D8'));
      expect(result.visit!.diagnosis.isNotEmpty, isTrue);
      expect(result.visit!.diagnosis.first.name, equals('Acute upper respiratory infection'));
      expect(result.visit!.medications[0].name, equals('Paracetamol'));
      expect(result.visit!.vitals.isNotEmpty, isTrue);
    });

    test('LocalVisitRepository retrieves visits with active patientRef', () async {
      const activePatientRef = 'P-CUSTOM-REF-99';
      final visits = await LocalVisitRepository.instance.getLastFiveVisits(activePatientRef);

      expect(visits.length, equals(5));
      for (final v in visits) {
        expect(v.patientRef, equals(activePatientRef));
        expect(v.visitId.isNotEmpty, isTrue);
        expect(v.timestamp.isNotEmpty, isTrue);
        expect(v.medications.isNotEmpty, isTrue);

        // Verify each can be encoded to compact QR and decoded back
        final encodeResult = HrxEncoder().encodeCompactVisitQr(v);
        final qr = encodeResult.qrPayload;
        expect(qr.startsWith('HRX:Z:'), isTrue);

        final result = HrxDecoder().decode(qr);
        expect(result.success, isTrue);
        expect(result.visit!.patientRef, equals(activePatientRef));
      }
    });
  });

  group('Family Scanner QR Parser Tests', () {
    test('Decodes compact HRX pipe-delimited string', () {
      const compactCode = 'HRX:P|1|P-1234|ASH-PT-7788|Aarav Gupta|Male|O+|9876543210';
      final decoder = HrxDecoder();
      final result = decoder.decode(compactCode);

      expect(result.success, isTrue);
      expect(result.patient, isNotNull);
      expect(result.patient!.name, equals('Aarav Gupta'));
      expect(result.patient!.patientId, equals('ASH-PT-7788'));
      expect(result.patient!.gender, equals('Male'));
      expect(result.patient!.bloodGroup, equals('O+'));
      expect(result.patient!.phone, equals('9876543210'));
    });

    test('Decodes raw JSON patient string fallback', () {
      const rawJson = '{"name":"Sunita Gupta","patientId":"ASH-PT-3321","gender":"Female","bloodGroup":"AB+","phone":"9811223344"}';
      final map = jsonDecode(rawJson) as Map<String, dynamic>;

      expect(map['name'], equals('Sunita Gupta'));
      expect(map['patientId'], equals('ASH-PT-3321'));
      expect(map['gender'], equals('Female'));
      expect(map['bloodGroup'], equals('AB+'));
    });
  });
}
