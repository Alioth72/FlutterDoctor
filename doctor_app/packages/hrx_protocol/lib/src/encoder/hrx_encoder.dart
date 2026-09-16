import 'dart:convert';
import 'dart:typed_data';
import '../compression/deflate_compressor.dart';
import '../crypto/aes_gcm.dart';
import '../crypto/key_provider.dart';
import '../models/patient_record.dart';
import '../models/visit_record.dart';
import '../protocol/capacity.dart';
import '../protocol/constants.dart';
import '../protocol/hrx_packet.dart';
import '../serialization/cbor_codec.dart';
import '../serialization/base45.dart';

/// Diagnostic statistics and results produced by HRX encoding.
class HrxEncodeResult {
  final String qrPayload;
  final int originalSize;
  final int serializedSize;
  final int compressedSize;
  final int encryptedSize;
  final int finalPayloadSize;
  final int qrVersion;
  final HrxCapacityStatus status;
  final double compressionRatio;
  final String compressionAlgorithm;
  final String encryptionAlgorithm;
  final String payloadEncoding;

  const HrxEncodeResult({
    required this.qrPayload,
    required this.originalSize,
    required this.serializedSize,
    required this.compressedSize,
    required this.encryptedSize,
    required this.finalPayloadSize,
    required this.qrVersion,
    required this.status,
    required this.compressionRatio,
    this.compressionAlgorithm = 'Deflate',
    this.encryptionAlgorithm = 'AES-256-GCM',
    this.payloadEncoding = 'Base64Url',
  });

  bool get isFits => status == HrxCapacityStatus.fits;

  Map<String, dynamic> toDiagnosticMap() => {
        'original_size': originalSize,
        'serialized_size': serializedSize,
        'compressed_size': compressedSize,
        'encrypted_size': encryptedSize,
        'final_payload_size': finalPayloadSize,
        'qr_version': qrVersion,
        'status': status == HrxCapacityStatus.fits ? 'FITS' : 'TOO_LARGE',
        'compression_ratio': '${(compressionRatio * 100).toStringAsFixed(1)}%',
        'compression': compressionAlgorithm,
        'encryption': encryptionAlgorithm,
        'encoding': payloadEncoding,
      };

  @override
  String toString() =>
      'HrxEncodeResult(size: $finalPayloadSize bytes, QR v$qrVersion, status: $status, encoding: $payloadEncoding)';
}

/// HRX Encoder implementing the complete encoding pipeline for medical records.
class HrxEncoder {
  final HrxKeyProvider keyProvider;

  HrxEncoder({HrxKeyProvider? keyProvider})
      : keyProvider = keyProvider ?? DevKeyProvider.instance;

  /// Encodes a Patient Identity QR into compact format.
  /// When [compact] is true, produces high-density pipe-delimited format (60-70 chars, QR v3).
  String encodePatientQr(PatientRecord patient, {bool compact = true}) {
    return patient.toQrString(compact: compact);
  }

  /// Encodes a VisitRecord through the full HRX pipeline:
  /// Validate -> Compact CBOR Serialize -> Deflate Compress -> AES-256-GCM Encrypt -> HMAC Sign -> QR Payload.
  /// When [useBase45] is true, encodes payload to RFC 9285 Base45 with 'HRX:45:' prefix.
  /// When [compact] is true, strips redundant empty fields and uses compact token keys.
  HrxEncodeResult encodeVisitQr(
    VisitRecord visit, {
    int keyId = HrxConstants.defaultKeyId,
    bool useBase45 = false,
    bool compact = true,
  }) {
    // 1. Calculate original JSON size for diagnostics
    final mapToEncode = compact ? visit.toCompactMap() : visit.toMap();
    final jsonStr = jsonEncode(visit.toMap());
    final originalBytes = utf8.encode(jsonStr);
    final originalSize = originalBytes.length;

    // 2. Compact CBOR serialization
    final serializedBytes = HrxCborCodec.encode(mapToEncode);
    final serializedSize = serializedBytes.length;

    // 3. Deflate compression
    final compressedBytes = HrxDeflateCompressor.compress(serializedBytes);
    final compressedSize = compressedBytes.length;

    // 4. AES-256-GCM encryption with unique random 12-byte nonce
    final encKey = keyProvider.getEncryptionKey(keyId);
    final nonce = HrxAesGcm.generateRandomNonce();

    // Associated Authenticated Data: recordId + patientRef
    final aad = utf8.encode('${visit.visitId}:${visit.patientRef}');
    final encryptedBytes = HrxAesGcm.encrypt(
      key: encKey,
      nonce: nonce,
      plaintext: compressedBytes,
      associatedData: Uint8List.fromList(aad),
    );
    final encryptedSize = encryptedBytes.length;

    // 5. Build HRX Packet & Sign with HMAC-SHA256
    final signKey = keyProvider.getSigningKey(keyId);
    final packet = HrxPacket(
      packetType: HrxConstants.packetTypeVisit,
      schemaVersion: HrxConstants.schemaVersion,
      keyId: keyId,
      compressionAlgorithm: HrxConstants.compressionDeflate,
      encryptionAlgorithm: HrxConstants.encryptionAes256Gcm,
      recordId: visit.visitId,
      patientRef: visit.patientRef,
      nonce: nonce,
      payload: encryptedBytes,
      signature: Uint8List(32), // Will be calculated by toBytes
    );

    final finalPacketBytes = packet.toBytes(signingKey: signKey);
    final finalSize = finalPacketBytes.length;

    // 6. Capacity Check
    final capacity = HrxCapacityChecker.checkCapacity(finalSize);

    // 7. QR Payload String (RFC 9285 Base45 or URL-safe Base64)
    final String qrString;
    final String encodingName;
    if (useBase45) {
      qrString = '${HrxConstants.qrPrefixBase45}${Base45.encode(finalPacketBytes)}';
      encodingName = 'Base45';
    } else {
      final base64String = base64Url.encode(finalPacketBytes);
      qrString = '${HrxConstants.qrPrefix}$base64String';
      encodingName = 'Base64Url';
    }

    final ratio = originalSize > 0 ? (compressedSize / originalSize) : 1.0;

    return HrxEncodeResult(
      qrPayload: qrString,
      originalSize: originalSize,
      serializedSize: serializedSize,
      compressedSize: compressedSize,
      encryptedSize: encryptedSize,
      finalPayloadSize: finalSize,
      qrVersion: capacity.estimatedQrVersion,
      status: capacity.status,
      compressionRatio: ratio,
      payloadEncoding: encodingName,
    );
  }

  /// Direct Built-in Compression Pipeline with Clinical Distillation for maximum scannability:
  /// Distilled Clinical JSON -> Built-in Deflate -> Base64Url -> 'HRX:Z:' QR payload.
  /// Produces ~210-240 characters (QR Version 8-10, ~49x49 to 57x57 dots vs previous 93x93 v19),
  /// with 3.6x fewer micro-dots for immediate offline scanning on all camera sensors.
  HrxEncodeResult encodeCompactVisitQr(VisitRecord visit) {
    // 1. Distilled high-density clinical schema (omits essays and redundant narrative)
    final mapToEncode = visit.toDistilledMap();
    final jsonStr = jsonEncode(mapToEncode);
    final originalBytes = utf8.encode(jsonStr);
    final originalSize = originalBytes.length;

    // 2. Built-in Deflate compression
    final compressedBytes = HrxDeflateCompressor.compress(Uint8List.fromList(originalBytes));
    final compressedSize = compressedBytes.length;

    // 3. Base64Url encoding with 'HRX:Z:' prefix
    final base64String = base64Url.encode(compressedBytes);
    final qrString = '${HrxConstants.qrPrefixCompressedVisit}$base64String';
    final finalSize = qrString.length;

    // 4. Capacity and QR Version estimation based on actual payload length
    final capacity = HrxCapacityChecker.checkCapacity(finalSize);

    final ratio = originalSize > 0 ? (compressedSize / originalSize) : 1.0;

    return HrxEncodeResult(
      qrPayload: qrString,
      originalSize: originalSize,
      serializedSize: originalSize,
      compressedSize: compressedSize,
      encryptedSize: compressedSize,
      finalPayloadSize: finalSize,
      qrVersion: capacity.estimatedQrVersion,
      status: capacity.status,
      compressionRatio: ratio,
      compressionAlgorithm: 'Deflate (Built-in)',
      encryptionAlgorithm: 'None (Direct Transport)',
      payloadEncoding: 'Base64Url',
    );
  }
}
