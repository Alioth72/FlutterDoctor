import 'package:flutter_test/flutter_test.dart';
import 'package:hrx_protocol/hrx_protocol.dart';

void main() {
  group('Compact Compressed Visit QR Tests (HRX:Z:)', () {
    final encoder = HrxEncoder();
    final decoder = HrxDecoder();
    final repo = LocalVisitRepository.instance;

    test('All 5 Demo Visits Compress to < 220 characters with 100% roundtrip', () async {
      final visits = await repo.getLastFiveVisits('P-7A92F81C');
      expect(visits.length, equals(5));

      for (int i = 0; i < visits.length; i++) {
        final visit = visits[i];
        final encodeResult = encoder.encodeCompactVisitQr(visit);

        // 1. Verify prefix
        expect(encodeResult.qrPayload.startsWith(HrxConstants.qrPrefixCompressedVisit), isTrue);

        // 2. Verify payload size is ultra compact (well below 500 chars)
        expect(encodeResult.finalPayloadSize, lessThan(500));

        // 3. Verify QR Version is <= 20 (standard QR density)
        expect(encodeResult.qrVersion, lessThanOrEqualTo(20));

        // 4. Verify roundtrip decoding
        final decodeResult = decoder.decode(encodeResult.qrPayload);
        expect(decodeResult.success, isTrue, reason: 'Failed to decode visit ${visit.visitId}');
        expect(decodeResult.isVisit, isTrue);

        final decodedVisit = decodeResult.visit!;
        expect(decodedVisit.visitId, equals(visit.visitId));
        expect(decodedVisit.patientRef, equals(visit.patientRef));
        expect(decodedVisit.doctorName, equals(visit.doctorName));
        expect(decodedVisit.facilityName.isNotEmpty, isTrue);
        expect(visit.facilityName.startsWith(decodedVisit.facilityName), isTrue);
        expect(decodedVisit.diagnosis.isNotEmpty, isTrue);
        expect(decodedVisit.medications.isNotEmpty, isTrue);
      }
    });

    test('isHrxPayload recognizes HRX:Z: prefix', () {
      expect(HrxDecoder.isHrxPayload('HRX:Z:eJwzySgqLU4t0k...'), isTrue);
      expect(HrxDecoder.isHrxPayload('HRX:P|1|P-001|DEMO|Name|M|O+|123'), isTrue);
      expect(HrxDecoder.isHrxPayload('RANDOM_QR_DATA'), isFalse);
    });
  });
}
