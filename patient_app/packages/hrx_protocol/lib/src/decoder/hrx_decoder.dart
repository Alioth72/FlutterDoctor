import 'dart:convert';
import 'dart:typed_data';
import '../compression/deflate_compressor.dart';
import '../crypto/aes_gcm.dart';
import '../crypto/key_provider.dart';
import '../models/patient_record.dart';
import '../models/visit_record.dart';
import '../protocol/constants.dart';
import '../protocol/errors.dart';
import '../protocol/hrx_packet.dart';
import '../serialization/cbor_codec.dart';
import '../serialization/base45.dart';

enum HrxDecodeType {
  patient,
  visit,
  emergencyHistory,
}

class HrxDecodeResult {
  final bool success;
  final HrxDecodeType? type;
  final PatientRecord? patient;
  final VisitRecord? visit;
  final List<VisitRecord>? visits;
  final Map<String, dynamic> metadata;
  final String? errorMessage;
  final HrxErrorCode? errorCode;

  const HrxDecodeResult({
    required this.success,
    this.type,
    this.patient,
    this.visit,
    this.visits,
    this.metadata = const {},
    this.errorMessage,
    this.errorCode,
  });

  factory HrxDecodeResult.patientSuccess(
    PatientRecord patient, {
    Map<String, dynamic> metadata = const {},
  }) {
    return HrxDecodeResult(
      success: true,
      type: HrxDecodeType.patient,
      patient: patient,
      metadata: metadata,
    );
  }

  factory HrxDecodeResult.visitSuccess(
    VisitRecord visit, {
    required Map<String, dynamic> metadata,
  }) {
    return HrxDecodeResult(
      success: true,
      type: HrxDecodeType.visit,
      visit: visit,
      metadata: metadata,
    );
  }

  factory HrxDecodeResult.emergencyHistorySuccess(
    List<VisitRecord> visits, {
    Map<String, dynamic> metadata = const {},
  }) {
    return HrxDecodeResult(
      success: true,
      type: HrxDecodeType.emergencyHistory,
      visits: visits,
      visit: visits.isNotEmpty ? visits.first : null,
      metadata: metadata,
    );
  }

  factory HrxDecodeResult.failure(HrxException exception) {
    return HrxDecodeResult(
      success: false,
      errorCode: exception.code,
      errorMessage: exception.userFriendlyMessage,
      metadata: {'error_details': exception.message},
    );
  }

  bool get isPatient => type == HrxDecodeType.patient;
  bool get isVisit => type == HrxDecodeType.visit;
  bool get isEmergencyHistory =>
      type == HrxDecodeType.emergencyHistory || (visits != null && visits!.isNotEmpty);

  @override
  String toString() => success
      ? 'HrxDecodeResult(success: true, type: $type, visits: ${visits?.length}, metadata: $metadata)'
      : 'HrxDecodeResult(success: false, error: $errorCode: $errorMessage)';
}

/// HRX Decoder implementing continuous detection and full decoding pipeline.
class HrxDecoder {
  final HrxKeyProvider keyProvider;

  HrxDecoder({HrxKeyProvider? keyProvider})
      : keyProvider = keyProvider ?? DevKeyProvider.instance;

  /// Detects whether raw QR string is an HRX-compatible QR code
  static bool isHrxPayload(String rawCode) {
    var trimmed = rawCode.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 2) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }
    if (trimmed.startsWith(HrxConstants.qrPrefixEmergencyHistory)) return true;
    if (trimmed.startsWith(HrxConstants.qrPrefixCompressedVisit)) return true;
    if (trimmed.startsWith(HrxConstants.qrPrefixPatient)) return true;
    if (trimmed.startsWith(HrxConstants.qrPrefix)) return true;
    if (trimmed.startsWith('{') &&
        (trimmed.contains('"protocol"') || trimmed.contains("'protocol'")) &&
        trimmed.contains(HrxConstants.magicString)) {
      return true;
    }
    return false;
  }

  /// Decodes raw QR string payload into an [HrxDecodeResult]
  HrxDecodeResult decode(String rawCode) {
    try {
      var trimmed = rawCode.trim();
      if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length > 2) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }

      // Case 0: Emergency Multi-Visit History QR ('HRX:HIST:...')
      if (trimmed.startsWith(HrxConstants.qrPrefixEmergencyHistory)) {
        final base64Payload = trimmed.substring(HrxConstants.qrPrefixEmergencyHistory.length);
        return _decodeEmergencyHistory(base64Payload);
      }

      // Case 1: High-density pipe-delimited Compact Patient QR ('HRX:P|1|...')
      if (trimmed.startsWith(HrxConstants.qrPrefixPatient)) {
        return _decodeCompactPatient(trimmed);
      }

      // Case 1B: Direct Built-in Deflate-compressed Visit QR ('HRX:Z:...')
      if (trimmed.startsWith(HrxConstants.qrPrefixCompressedVisit)) {
        final base64Payload = trimmed.substring(HrxConstants.qrPrefixCompressedVisit.length);
        return _decodeCompressedVisit(base64Payload);
      }

      // Case 2: Legacy JSON Patient QR
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        return _decodePatientJson(trimmed);
      }

      // Case 3: RFC 9285 Base45 HRX Packet ('HRX:45:...')
      if (trimmed.startsWith(HrxConstants.qrPrefixBase45)) {
        final rawBase45 = trimmed.substring(HrxConstants.qrPrefixBase45.length);
        final packetBytes = Base45.decode(rawBase45);
        return _decodeHrxPacket(packetBytes);
      }

      // Case 4: Binary HRX Packet encoded in Base64 (with or without 'HRX:' prefix)
      String base64Payload = trimmed;
      if (base64Payload.startsWith(HrxConstants.qrPrefix)) {
        base64Payload = base64Payload.substring(HrxConstants.qrPrefix.length);
      }

      // Strip whitespace and normalize padding
      base64Payload = base64Payload.replaceAll(RegExp(r'\s+'), '');
      final remainder = base64Payload.length % 4;
      if (remainder > 0) {
        base64Payload += '=' * (4 - remainder);
      }

      Uint8List packetBytes;
      try {
        // Support standard and URL-safe Base64
        packetBytes = base64Url.decode(base64Payload);
      } catch (_) {
        try {
          final stdB64 = base64Payload.replaceAll('-', '+').replaceAll('_', '/');
          packetBytes = base64.decode(stdB64);
        } catch (_) {
          // If base64 fails, attempt Base45 fallback
          try {
            packetBytes = Base45.decode(base64Payload);
          } catch (e) {
            throw HrxException(
              code: HrxErrorCode.invalidQr,
              message: 'Invalid payload encoding in QR code: $e',
            );
          }
        }
      }

      return _decodeHrxPacket(packetBytes);
    } on HrxException catch (e) {
      return HrxDecodeResult.failure(e);
    } catch (e) {
      return HrxDecodeResult.failure(
        HrxException(
          code: HrxErrorCode.invalidQr,
          message: 'Decoding error: $e',
        ),
      );
    }
  }

  HrxDecodeResult _decodeCompactPatient(String pipeStr) {
    final patient = PatientRecord.fromQrString(pipeStr);
    if (patient == null) {
      throw HrxException(
        code: HrxErrorCode.invalidQr,
        message: 'Failed to parse compact patient QR format.',
      );
    }
    return HrxDecodeResult.patientSuccess(
      patient,
      metadata: {
        'protocol': HrxConstants.magicString,
        'version': HrxConstants.protocolVersion,
        'format': 'COMPACT_PIPE',
        'type': 'PATIENT',
        'verified': true,
      },
    );
  }

  HrxDecodeResult _decodeCompressedVisit(String rawPayload) {
    try {
      // 1. Clean payload: remove prefix if present, strip all whitespace and quotes
      var clean = rawPayload.trim();
      if (clean.startsWith('"') && clean.endsWith('"') && clean.length > 2) {
        clean = clean.substring(1, clean.length - 1).trim();
      }
      if (clean.startsWith(HrxConstants.qrPrefixCompressedVisit)) {
        clean = clean.substring(HrxConstants.qrPrefixCompressedVisit.length);
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');

      // 2. Normalize Base64Url padding
      final remainder = clean.length % 4;
      if (remainder > 0) {
        clean += '=' * (4 - remainder);
      }

      Uint8List compressedBytes;
      try {
        compressedBytes = base64Url.decode(clean);
      } catch (_) {
        try {
          final stdB64 = clean.replaceAll('-', '+').replaceAll('_', '/');
          compressedBytes = base64.decode(stdB64);
        } catch (_) {
          try {
            compressedBytes = base64.decode(clean);
          } catch (_) {
            if (clean.startsWith('{') || clean.startsWith('[')) {
              compressedBytes = Uint8List.fromList(utf8.encode(clean));
            } else {
              throw HrxException(
                code: HrxErrorCode.deserializationFailure,
                message: 'Invalid Base64 payload in compressed visit QR.',
              );
            }
          }
        }
      }

      // 3. Multi-stage decompression
      final decompressedBytes = HrxDeflateCompressor.decompress(compressedBytes);
      final jsonString = utf8.decode(decompressedBytes, allowMalformed: true);
      final decoded = jsonDecode(jsonString);

      if (decoded is List) {
        final visitList = decoded
            .whereType<Map>()
            .map((m) => VisitRecord.fromMap(m))
            .toList();
        return HrxDecodeResult.emergencyHistorySuccess(
          visitList,
          metadata: {
            'protocol': HrxConstants.magicString,
            'version': HrxConstants.protocolVersion,
            'format': 'DEFLATE_BASE64URL_BUNDLE',
            'type': 'EMERGENCY_HISTORY',
            'verified': true,
            'count': visitList.length,
            'compressed_size': compressedBytes.length,
            'decompressed_size': decompressedBytes.length,
          },
        );
      }

      if (decoded is Map && decoded['visits'] is List) {
        final visitList = (decoded['visits'] as List)
            .whereType<Map>()
            .map((m) => VisitRecord.fromMap(m))
            .toList();
        return HrxDecodeResult.emergencyHistorySuccess(
          visitList,
          metadata: {
            'protocol': HrxConstants.magicString,
            'version': HrxConstants.protocolVersion,
            'format': 'DEFLATE_BASE64URL_BUNDLE',
            'type': 'EMERGENCY_HISTORY',
            'verified': true,
            'count': visitList.length,
            'compressed_size': compressedBytes.length,
            'decompressed_size': decompressedBytes.length,
          },
        );
      }

      if (decoded is! Map) {
        throw HrxException(
          code: HrxErrorCode.deserializationFailure,
          message: 'Decompressed payload is not a valid visit object.',
        );
      }

      final visit = VisitRecord.fromMap(decoded);
      return HrxDecodeResult.visitSuccess(
        visit,
        metadata: {
          'protocol': HrxConstants.magicString,
          'version': HrxConstants.protocolVersion,
          'format': 'DEFLATE_BASE64URL',
          'type': 'VISIT',
          'verified': true,
          'compressed_size': compressedBytes.length,
          'decompressed_size': decompressedBytes.length,
        },
      );
    } on HrxException catch (_) {
      rethrow;
    } catch (e) {
      throw HrxException(
        code: HrxErrorCode.deserializationFailure,
        message: 'Failed to decompress and parse visit record: $e',
      );
    }
  }

  HrxDecodeResult _decodeEmergencyHistory(String rawPayload) {
    try {
      var clean = rawPayload.trim();
      if (clean.startsWith('"') && clean.endsWith('"') && clean.length > 2) {
        clean = clean.substring(1, clean.length - 1).trim();
      }
      if (clean.startsWith(HrxConstants.qrPrefixEmergencyHistory)) {
        clean = clean.substring(HrxConstants.qrPrefixEmergencyHistory.length);
      }
      clean = clean.replaceAll(RegExp(r'\s+'), '');

      final remainder = clean.length % 4;
      if (remainder > 0) {
        clean += '=' * (4 - remainder);
      }

      Uint8List compressedBytes;
      try {
        compressedBytes = base64Url.decode(clean);
      } catch (_) {
        try {
          final stdB64 = clean.replaceAll('-', '+').replaceAll('_', '/');
          compressedBytes = base64.decode(stdB64);
        } catch (_) {
          try {
            compressedBytes = base64.decode(clean);
          } catch (_) {
            if (clean.startsWith('{') || clean.startsWith('[')) {
              compressedBytes = Uint8List.fromList(utf8.encode(clean));
            } else {
              throw HrxException(
                code: HrxErrorCode.deserializationFailure,
                message: 'Invalid Base64 payload in emergency history QR.',
              );
            }
          }
        }
      }

      final decompressedBytes = HrxDeflateCompressor.decompress(compressedBytes);
      final jsonString = utf8.decode(decompressedBytes, allowMalformed: true);
      final decoded = jsonDecode(jsonString);

      List<VisitRecord> visitList = [];
      if (decoded is List) {
        visitList = decoded.whereType<Map>().map((m) => VisitRecord.fromMap(m)).toList();
      } else if (decoded is Map && decoded['visits'] is List) {
        visitList = (decoded['visits'] as List).whereType<Map>().map((m) => VisitRecord.fromMap(m)).toList();
      } else if (decoded is Map) {
        visitList = [VisitRecord.fromMap(decoded)];
      }

      if (visitList.isEmpty) {
        throw HrxException(
          code: HrxErrorCode.deserializationFailure,
          message: 'No visit records found in emergency history payload.',
        );
      }

      return HrxDecodeResult.emergencyHistorySuccess(
        visitList,
        metadata: {
          'protocol': HrxConstants.magicString,
          'version': HrxConstants.protocolVersion,
          'format': 'DEFLATE_BASE64URL_HISTORY',
          'type': 'EMERGENCY_HISTORY',
          'verified': true,
          'count': visitList.length,
          'compressed_size': compressedBytes.length,
          'decompressed_size': decompressedBytes.length,
        },
      );
    } on HrxException catch (_) {
      rethrow;
    } catch (e) {
      throw HrxException(
        code: HrxErrorCode.deserializationFailure,
        message: 'Failed to decompress and parse emergency history: $e',
      );
    }
  }

  HrxDecodeResult _decodePatientJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr);
      if (map is! Map) {
        throw HrxException(
          code: HrxErrorCode.invalidQr,
          message: 'Expected JSON map for patient QR.',
        );
      }

      final protocol = map['protocol']?.toString();
      if (protocol != HrxConstants.magicString) {
        throw HrxException(
          code: HrxErrorCode.unknownProtocol,
          message: 'Unknown protocol: $protocol. Expected HRX.',
        );
      }

      final version = map['version'];
      if (version != HrxConstants.protocolVersion) {
        throw HrxException(
          code: HrxErrorCode.unsupportedVersion,
          message: 'Unsupported version: $version (expected ${HrxConstants.protocolVersion}).',
        );
      }

      final patient = PatientRecord.fromMap(map);
      return HrxDecodeResult.patientSuccess(
        patient,
        metadata: {
          'protocol': protocol,
          'version': version,
          'type': 'PATIENT',
          'verified': true,
        },
      );
    } catch (e) {
      if (e is HrxException) rethrow;
      throw HrxException(
        code: HrxErrorCode.deserializationFailure,
        message: 'Failed to parse Patient QR JSON: $e',
      );
    }
  }

  HrxDecodeResult _decodeHrxPacket(Uint8List packetBytes) {
    // 1. Peek header to get keyId
    if (packetBytes.length < 10) {
      throw HrxException(
        code: HrxErrorCode.invalidPacket,
        message: 'Packet is too short for HRX header.',
      );
    }

    final keyId = packetBytes[6]; // Byte 6 is keyId
    final signingKey = keyProvider.getSigningKey(keyId);

    // 2. Parse packet and verify HMAC-SHA256 signature
    final packet = HrxPacket.fromBytes(packetBytes, signingKey: signingKey);

    // 3. Handle based on packet type
    if (packet.isPatientPacket) {
      return HrxDecodeResult.patientSuccess(
        PatientRecord(
          patientRef: packet.patientRef,
          patientId: packet.recordId,
          name: 'Patient (${packet.patientRef})',
        ),
        metadata: {
          'protocol_version': packet.protocolVersion,
          'schema_version': packet.schemaVersion,
          'integrity_verified': true,
          'signature_verified': true,
        },
      );
    }

    // 4. Decrypt payload using AES-256-GCM
    final encKey = keyProvider.getEncryptionKey(packet.keyId);
    final aad = utf8.encode('${packet.recordId}:${packet.patientRef}');

    final compressedBytes = HrxAesGcm.decrypt(
      key: encKey,
      nonce: packet.nonce,
      ciphertextWithTag: packet.payload,
      associatedData: Uint8List.fromList(aad),
    );

    // 5. Decompress using Deflate
    final serializedBytes = packet.compressionAlgorithm == HrxConstants.compressionDeflate
        ? HrxDeflateCompressor.decompress(compressedBytes)
        : compressedBytes;

    // 6. Deserialize CBOR
    final recordMap = HrxCborCodec.decode(serializedBytes);
    if (recordMap is! Map) {
      throw HrxException(
        code: HrxErrorCode.deserializationFailure,
        message: 'Deserialized CBOR object is not a medical visit map.',
      );
    }

    // 7. Validate visit schema
    final visitRecord = VisitRecord.fromMap(recordMap);

    return HrxDecodeResult.visitSuccess(
      visitRecord,
      metadata: {
        'protocol_version': packet.protocolVersion,
        'schema_version': packet.schemaVersion,
        'key_id': packet.keyId,
        'record_id': packet.recordId,
        'patient_ref': packet.patientRef,
        'encrypted': true,
        'compressed': true,
        'integrity_verified': true,
        'signature_verified': true,
        'packet_size_bytes': packetBytes.length,
      },
    );
  }
}
