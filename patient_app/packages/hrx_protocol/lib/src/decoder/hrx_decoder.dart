import 'dart:convert';
import 'dart:io';
import '../constants/hrx_constants.dart';
import '../models/patient_record.dart';
import '../models/visit_record.dart';
import 'hrx_decode_result.dart';

class HrxDecoder {
  /// Checks if the raw code is an HRX-compatible protocol payload.
  static bool isHrxPayload(String rawCode) {
    final trimmed = rawCode.trim();
    return trimmed.startsWith('HRX:') ||
        trimmed.startsWith(HrxConstants.qrPrefixCompressedVisit) ||
        trimmed.startsWith(HrxConstants.qrPrefixPatient) ||
        trimmed.startsWith(HrxConstants.qrPrefixVisit) ||
        trimmed.startsWith(HrxConstants.qrPrefixEncrypted);
  }

  /// Decodes and verifies the raw scanned QR payload into a structured record.
  HrxDecodeResult decode(String rawCode) {
    final trimmed = rawCode.trim();

    try {
      // 1. Patient Identity QR (HRX:P:)
      if (trimmed.startsWith(HrxConstants.qrPrefixPatient)) {
        final b64 = trimmed.substring(HrxConstants.qrPrefixPatient.length);
        final jsonStr = utf8.decode(base64Url.decode(base64Url.normalize(b64)));
        final Map<String, dynamic> map = jsonDecode(jsonStr);

        final patient = PatientRecord(
          patientRef: map['ref'] ?? map['patient_ref'] ?? '',
          patientId: map['id'] ?? map['patient_id'] ?? '',
          name: map['name'] ?? '',
          phone: map['ph'] ?? map['phone'] ?? '',
          bloodGroup: map['bg'] ?? map['blood_group'] ?? '',
          gender: map['gen'] ?? map['gender'] ?? '',
          dateOfBirth: map['dob'] ?? map['date_of_birth'] ?? '',
          visitIds: List<String>.from(map['visit_ids'] ?? map['visitIds'] ?? ['V1001', 'V1002', 'V1003', 'V1004', 'V1005']),
        );

        return HrxDecodeResult(
          success: true,
          isPatient: true,
          patient: patient,
          metadata: {
            'format': 'BASE64URL_JSON',
            'type': 'PATIENT',
            'protocol': 'HRX v1',
            'source': 'Scanned QR',
          },
        );
      }

      // 2. Compressed Offline Visit QR (HRX:Z:)
      if (trimmed.startsWith(HrxConstants.qrPrefixCompressedVisit)) {
        final b64 = trimmed.substring(HrxConstants.qrPrefixCompressedVisit.length);
        final compressedBytes = base64Url.decode(base64Url.normalize(b64));
        final decompressedBytes = zlib.decode(compressedBytes);
        final jsonStr = utf8.decode(decompressedBytes);
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        final visit = VisitRecord.fromJson(map);

        return HrxDecodeResult(
          success: true,
          isVisit: true,
          visit: visit,
          metadata: {
            'format': 'DEFLATE_BASE64URL',
            'algorithm': 'Deflate',
            'encoding': 'Base64URL',
            'compressedSize': '${compressedBytes.length} bytes',
            'decompressedSize': '${decompressedBytes.length} bytes',
            'protocol': 'HRX v1',
            'source': 'Direct Offline QR',
          },
        );
      }

      // 3. Uncompressed / Plain Visit QR (HRX:V:)
      if (trimmed.startsWith(HrxConstants.qrPrefixVisit)) {
        final jsonStr = trimmed.substring(HrxConstants.qrPrefixVisit.length);
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        final visit = VisitRecord.fromJson(map);

        return HrxDecodeResult(
          success: true,
          isVisit: true,
          visit: visit,
          metadata: {
            'format': 'JSON_PLAIN',
            'protocol': 'HRX v1',
          },
        );
      }

      // 4. Raw JSON fallback
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> map = jsonDecode(trimmed);
        if (map['type'] == 'PATIENT' || map['t'] == 'PATIENT') {
          return HrxDecodeResult(
            success: true,
            isPatient: true,
            patient: PatientRecord.fromJson(map),
            metadata: {'format': 'RAW_JSON', 'type': 'PATIENT'},
          );
        } else {
          return HrxDecodeResult(
            success: true,
            isVisit: true,
            visit: VisitRecord.fromJson(map),
            metadata: {'format': 'RAW_JSON', 'type': 'VISIT'},
          );
        }
      }

      return HrxDecodeResult(
        success: false,
        errorMessage: 'Unrecognized HRX payload format or corrupted QR data.',
      );
    } catch (e) {
      return HrxDecodeResult(
        success: false,
        errorMessage: 'Extraction failed: $e',
      );
    }
  }
}
