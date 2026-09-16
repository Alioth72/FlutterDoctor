import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrx_protocol/hrx_protocol.dart';

class WrongKeyProvider implements HrxKeyProvider {
  @override
  Uint8List getEncryptionKey(int keyId) => Uint8List(32); // All zeros

  @override
  Uint8List getSigningKey(int keyId) => Uint8List(32); // All zeros
}

void main() {
  group('1. Patient QR Tests', () {
    test('Patient Identity QR Encode and Decode', () {
      final encoder = HrxEncoder();
      final decoder = HrxDecoder();
      const patient = LocalPatientRepository.defaultPatient;

      final qrString = encoder.encodePatientQr(patient);
      expect(HrxDecoder.isHrxPayload(qrString), isTrue);

      final result = decoder.decode(qrString);
      expect(result.success, isTrue);
      expect(result.isPatient, isTrue);
      expect(result.patient, isNotNull);
      expect(result.patient!.patientRef, equals(patient.patientRef));
      expect(result.patient!.patientId, equals(patient.patientId));
      expect(result.patient!.name, equals(patient.name));
    });
  });

  group('2. Round-Trip Encode -> Decode for All 5 Demo Visits', () {
    final encoder = HrxEncoder();
    final decoder = HrxDecoder();
    final repo = LocalVisitRepository.instance;

    test('Visit 1 (Small) Round-Trip', () async {
      final visit = await repo.getVisitById('V1001');
      expect(visit, isNotNull);

      final encoded = encoder.encodeVisitQr(visit!);
      expect(encoded.isFits, isTrue);
      expect(encoded.qrPayload.startsWith(HrxConstants.qrPrefix), isTrue);

      final decoded = decoder.decode(encoded.qrPayload);
      expect(decoded.success, isTrue);
      expect(decoded.isVisit, isTrue);
      expect(decoded.visit!.visitId, equals(visit.visitId));
      expect(decoded.visit!.patientRef, equals(visit.patientRef));
      expect(decoded.visit!.diagnosis.length, equals(visit.diagnosis.length));
      expect(decoded.visit!.medications.length, equals(visit.medications.length));
      expect(decoded.visit!.medications.first.name, equals(visit.medications.first.name));
      expect(decoded.metadata['integrity_verified'], isTrue);
      expect(decoded.metadata['encrypted'], isTrue);
      expect(decoded.metadata['compressed'], isTrue);
    });

    test('Visit 2 (Medium) Round-Trip', () async {
      final visit = await repo.getVisitById('V1002');
      expect(visit, isNotNull);

      final encoded = encoder.encodeVisitQr(visit!);
      expect(encoded.isFits, isTrue);

      final decoded = decoder.decode(encoded.qrPayload);
      expect(decoded.success, isTrue);
      expect(decoded.visit!.visitId, equals('V1002'));
      expect(decoded.visit!.vitals['blood_pressure'], equals('138/88'));
      expect(decoded.visit!.labTests.length, equals(visit.labTests.length));
    });

    test('Visit 3 (Larger) Round-Trip', () async {
      final visit = await repo.getVisitById('V1003');
      expect(visit, isNotNull);

      final encoded = encoder.encodeVisitQr(visit!);
      expect(encoded.isFits, isTrue);

      final decoded = decoder.decode(encoded.qrPayload);
      expect(decoded.success, isTrue);
      expect(decoded.visit!.visitId, equals('V1003'));
      expect(decoded.visit!.allergies.first, contains('Penicillin'));
      expect(decoded.visit!.diagnosis.length, equals(2));
    });

    test('Visit 4 (Large) Round-Trip', () async {
      final visit = await repo.getVisitById('V1004');
      expect(visit, isNotNull);

      final encoded = encoder.encodeVisitQr(visit!);
      expect(encoded.isFits, isTrue);

      final decoded = decoder.decode(encoded.qrPayload);
      expect(decoded.success, isTrue);
      expect(decoded.visit!.visitId, equals('V1004'));
      expect(decoded.visit!.medications.length, equals(3));
    });

    test('Visit 5 (Stress Test) Round-Trip', () async {
      final visit = await repo.getVisitById('V1005');
      expect(visit, isNotNull);

      final encoded = encoder.encodeVisitQr(visit!);
      expect(encoded.isFits, isTrue);

      final decoded = decoder.decode(encoded.qrPayload);
      expect(decoded.success, isTrue);
      expect(decoded.visit!.visitId, equals('V1005'));
      expect(decoded.visit!.medications.length, equals(5));
      expect(decoded.visit!.diagnosis.length, equals(3));
    });
  });

  group('3. Tamper Detection Tests', () {
    test('Modifying one byte in payload causes integrity failure', () async {
      final encoder = HrxEncoder();
      final decoder = HrxDecoder();
      final visit = (await LocalVisitRepository.instance.getVisitById('V1001'))!;

      final encoded = encoder.encodeVisitQr(visit);
      final rawBase64 = encoded.qrPayload.substring(HrxConstants.qrPrefix.length);
      final bytes = Uint8List.fromList(base64Url.decode(rawBase64));

      // Tamper one byte in the middle of ciphertext
      bytes[bytes.length - 40] ^= 0xFF;

      final tamperedPayload = '${HrxConstants.qrPrefix}${base64Url.encode(bytes)}';
      final result = decoder.decode(tamperedPayload);

      expect(result.success, isFalse);
      expect(result.errorCode, equals(HrxErrorCode.integrityFailure));
      expect(result.visit, isNull);
    });
  });

  group('4. Wrong Key Test', () {
    test('Decoding with wrong development key triggers failure', () async {
      final encoder = HrxEncoder();
      final wrongDecoder = HrxDecoder(keyProvider: WrongKeyProvider());
      final visit = (await LocalVisitRepository.instance.getVisitById('V1001'))!;

      final encoded = encoder.encodeVisitQr(visit);
      final result = wrongDecoder.decode(encoded.qrPayload);

      expect(result.success, isFalse);
      expect(
        result.errorCode == HrxErrorCode.integrityFailure ||
            result.errorCode == HrxErrorCode.decryptionFailure,
        isTrue,
      );
      expect(result.visit, isNull);
    });
  });

  group('5. Protocol and Version Tests', () {
    test('Unknown protocol string is rejected', () {
      final decoder = HrxDecoder();
      final result = decoder.decode('{"protocol":"UNKNOWN_XYZ","version":1}');
      expect(result.success, isFalse);
      expect(result.errorCode, equals(HrxErrorCode.unknownProtocol));
    });

    test('Unsupported protocol version v999 is rejected gracefully', () {
      final decoder = HrxDecoder();
      final result = decoder.decode('{"protocol":"HRX","version":999,"type":"PATIENT"}');
      expect(result.success, isFalse);
      expect(result.errorCode, equals(HrxErrorCode.unsupportedVersion));
    });
  });

  group('6. Capacity Checker & Oversized Visit Test', () {
    test('Oversized visit produces status TOO_LARGE', () {
      final oversized = LocalVisitRepository.createOversizedVisit();
      final encoder = HrxEncoder();
      final result = encoder.encodeVisitQr(oversized);

      expect(result.isFits, isFalse);
      expect(result.status, equals(HrxCapacityStatus.tooLarge));
      expect(result.finalPayloadSize > HrxConstants.maxQrByteCapacity, isTrue);
    });
  });

  group('7. Five-Visit FIFO Rotation Test', () {
    test('Adding a 6th visit shifts FIFO slots and maintains exactly 5 visits', () async {
      final repo = LocalVisitRepository.instance;
      final initialVisits = await repo.getLastFiveVisits('P-7A92F81C');
      expect(initialVisits.length, equals(5));
      expect(initialVisits.first.visitId, equals('V1001'));

      const newVisit = VisitRecord(
        visitId: 'V1006_NEW',
        patientRef: 'P-7A92F81C',
        doctorRef: 'DOC-NEW',
        timestamp: '2026-09-14T10:00:00Z',
        chiefComplaints: ['Follow up test'],
      );

      await repo.addVisit(newVisit);

      final updatedVisits = await repo.getLastFiveVisits('P-7A92F81C');
      expect(updatedVisits.length, equals(5));
      expect(updatedVisits[0].visitId, equals('V1006_NEW'));
      expect(updatedVisits[1].visitId, equals('V1001'));
      expect(updatedVisits[2].visitId, equals('V1002'));
      expect(updatedVisits[3].visitId, equals('V1003'));
      expect(updatedVisits[4].visitId, equals('V1004'));
      // V1005 has rotated out
      expect(updatedVisits.any((v) => v.visitId == 'V1005'), isFalse);
    });
  });

  group('8. RFC 9285 Base45 & Compact Representation Tests', () {
    test('Base45 roundtrip encoding and decoding matches byte input', () {
      final sample = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x21]); // "Hello!"
      final encoded = Base45.encode(sample);
      expect(encoded.isNotEmpty, isTrue);

      final decoded = Base45.decode(encoded);
      expect(decoded, equals(sample));
    });

    test('Base45 Visit QR Round-Trip encode and decode', () async {
      final encoder = HrxEncoder();
      final decoder = HrxDecoder();
      final visit = (await LocalVisitRepository.instance.getVisitById('V1001'))!;

      final result = encoder.encodeVisitQr(visit, useBase45: true);
      expect(result.qrPayload.startsWith(HrxConstants.qrPrefixBase45), isTrue);
      expect(result.payloadEncoding, equals('Base45'));

      final decodeResult = decoder.decode(result.qrPayload);
      expect(decodeResult.success, isTrue);
      expect(decodeResult.isVisit, isTrue);
      expect(decodeResult.visit!.visitId, equals('V1001'));
    });

    test('Dual support for Compact Pipe Patient QR and Legacy JSON Patient QR', () {
      final decoder = HrxDecoder();
      const patient = LocalPatientRepository.defaultPatient;

      // 1. Compact format
      final compactQr = patient.toCompactQrString();
      expect(compactQr.startsWith(HrxConstants.qrPrefixPatient), isTrue);
      final res1 = decoder.decode(compactQr);
      expect(res1.success, isTrue);
      expect(res1.patient!.patientRef, equals(patient.patientRef));
      expect(res1.patient!.name, equals(patient.name));

      // 2. Legacy JSON format
      final legacyQr = patient.toQrString(compact: false);
      expect(legacyQr.startsWith('{'), isTrue);
      final res2 = decoder.decode(legacyQr);
      expect(res2.success, isTrue);
      expect(res2.patient!.patientRef, equals(patient.patientRef));
    });
  });
}
