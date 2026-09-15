import 'dart:convert';
import 'dart:io';
import '../constants/hrx_constants.dart';
import '../models/patient_record.dart';
import '../models/visit_record.dart';
import 'hrx_encode_result.dart';

class HrxEncoder {
  /// Encodes a patient record into a scannable HRX Patient Identity QR payload.
  String encodePatientQr(PatientRecord record, {bool compact = true}) {
    final payload = {
      'p': HrxConstants.protocol,
      'v': HrxConstants.version,
      't': HrxConstants.typePatient,
      'ref': record.patientRef,
      'id': record.patientId,
      'name': record.name,
      'ph': record.phone,
      'bg': record.bloodGroup,
      'gen': record.gender,
      'dob': record.dateOfBirth,
    };
    final jsonStr = jsonEncode(payload);
    final b64 = base64Url.encode(utf8.encode(jsonStr));
    return '${HrxConstants.qrPrefixPatient}$b64';
  }

  /// Compresses and encodes a full clinical visit into a high-density, camera-scannable QR payload.
  HrxEncodeResult encodeCompactVisitQr(VisitRecord record) {
    final map = record.toJson();
    final jsonStr = jsonEncode(map);
    final originalBytes = utf8.encode(jsonStr);

    // Deflate compression
    final compressedBytes = zlib.encode(originalBytes);
    final b64 = base64Url.encode(compressedBytes);
    final qrPayload = '${HrxConstants.qrPrefixCompressedVisit}$b64';

    final originalSize = originalBytes.length;
    final compressedSize = compressedBytes.length;
    final finalPayloadSize = qrPayload.length;
    final compressionRatio = originalSize > 0 ? (originalSize - compressedSize) / originalSize : 0.0;

    // Estimate standard QR Matrix Version based on character capacity at Medium ECC
    int qrVersion = 8;
    if (finalPayloadSize < 110) {
      qrVersion = 6;
    } else if (finalPayloadSize < 170) {
      qrVersion = 8;
    } else if (finalPayloadSize < 250) {
      qrVersion = 10;
    } else if (finalPayloadSize < 340) {
      qrVersion = 12;
    } else {
      qrVersion = 14;
    }

    return HrxEncodeResult(
      qrPayload: qrPayload,
      qrVersion: qrVersion,
      originalSize: originalSize,
      compressedSize: compressedSize,
      compressionAlgorithm: 'Deflate',
      finalPayloadSize: finalPayloadSize,
      payloadEncoding: 'Base64URL',
      compressionRatio: compressionRatio,
    );
  }
}
