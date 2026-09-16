import 'dart:convert';
import 'dart:typed_data';
import '../crypto/sha256_hmac.dart';
import 'constants.dart';
import 'errors.dart';

/// Represents a validated, structured HRX binary packet.
class HrxPacket {
  final String magic;
  final int protocolVersion;
  final int packetType;
  final int schemaVersion;
  final int keyId;
  final int compressionAlgorithm;
  final int encryptionAlgorithm;
  final String recordId;
  final String patientRef;
  final Uint8List nonce;
  final Uint8List payload;
  final Uint8List signature;

  const HrxPacket({
    this.magic = HrxConstants.magicString,
    this.protocolVersion = HrxConstants.protocolVersion,
    required this.packetType,
    this.schemaVersion = HrxConstants.schemaVersion,
    this.keyId = HrxConstants.defaultKeyId,
    this.compressionAlgorithm = HrxConstants.compressionDeflate,
    this.encryptionAlgorithm = HrxConstants.encryptionAes256Gcm,
    required this.recordId,
    required this.patientRef,
    required this.nonce,
    required this.payload,
    required this.signature,
  });

  bool get isPatientPacket => packetType == HrxConstants.packetTypePatient;
  bool get isVisitPacket => packetType == HrxConstants.packetTypeVisit;

  /// Serializes the packet into binary bytes and calculates HMAC-SHA256 signature.
  Uint8List toBytes({required Uint8List signingKey}) {
    final builder = BytesBuilder();

    // 1. Magic (3 bytes: 'H', 'R', 'X')
    builder.add(HrxConstants.magicBytes);

    // 2. Protocol & Schema versions (1 byte each)
    builder.addByte(protocolVersion);
    builder.addByte(packetType);
    builder.addByte(schemaVersion);

    // 3. Security & Algorithm headers (1 byte each)
    builder.addByte(keyId);
    builder.addByte(compressionAlgorithm);
    builder.addByte(encryptionAlgorithm);

    // 4. Record ID (1-byte length + UTF-8 bytes)
    final recordIdBytes = utf8.encode(recordId);
    builder.addByte(recordIdBytes.length);
    builder.add(recordIdBytes);

    // 5. Patient Ref (1-byte length + UTF-8 bytes)
    final patientRefBytes = utf8.encode(patientRef);
    builder.addByte(patientRefBytes.length);
    builder.add(patientRefBytes);

    // 6. Nonce (12 bytes)
    if (nonce.length != HrxConstants.nonceLength) {
      throw HrxException(
        code: HrxErrorCode.invalidPacket,
        message: 'Invalid nonce length: ${nonce.length} (expected ${HrxConstants.nonceLength})',
      );
    }
    builder.add(nonce);

    // 7. Payload length (2 bytes Big-Endian) + Payload
    final payloadLengthBd = ByteData(2);
    payloadLengthBd.setUint16(0, payload.length, Endian.big);
    builder.add(payloadLengthBd.buffer.asUint8List());
    builder.add(payload);

    // Bytes to sign
    final signedContent = builder.toBytes();

    // 8. HMAC-SHA256 Signature (32 bytes)
    final computedSig = HrxSha256.hmac(signingKey, signedContent);
    builder.add(computedSig);

    return builder.toBytes();
  }

  /// Parses binary bytes into an [HrxPacket] and verifies HMAC-SHA256 signature.
  static HrxPacket fromBytes(Uint8List bytes, {required Uint8List signingKey}) {
    // Minimum size: 3 (magic) + 1 + 1 + 1 + 1 + 1 + 1 + 1 (rec_len) + 1 (pat_len) + 12 (nonce) + 2 (pay_len) + 32 (sig) = 57 bytes
    if (bytes.length < 57) {
      throw HrxException(
        code: HrxErrorCode.invalidPacket,
        message: 'Packet length ${bytes.length} is too short to be an HRX packet.',
      );
    }

    // 1. Verify Magic
    if (bytes[0] != 0x48 || bytes[1] != 0x52 || bytes[2] != 0x58) {
      throw HrxException(
        code: HrxErrorCode.unknownProtocol,
        message: 'Invalid magic header. Expected HRX format.',
      );
    }

    // Check signature first (last 32 bytes)
    final contentLen = bytes.length - HrxConstants.signatureLength;
    final signedContent = Uint8List.sublistView(bytes, 0, contentLen);
    final expectedSignature = Uint8List.sublistView(bytes, contentLen);

    final computedSignature = HrxSha256.hmac(signingKey, signedContent);
    if (!HrxSha256.constantTimeEquals(computedSignature, expectedSignature)) {
      throw HrxException(
        code: HrxErrorCode.integrityFailure,
        message: 'HRX Packet signature verification failed. The packet has been tampered with or corrupted.',
      );
    }

    int offset = 3;
    final protocolVersion = bytes[offset++];
    if (protocolVersion != HrxConstants.protocolVersion) {
      throw HrxException(
        code: HrxErrorCode.unsupportedVersion,
        message: 'Unsupported protocol version $protocolVersion (current is ${HrxConstants.protocolVersion}).',
      );
    }

    final packetType = bytes[offset++];
    final schemaVersion = bytes[offset++];
    final keyId = bytes[offset++];
    final compressionAlgorithm = bytes[offset++];
    final encryptionAlgorithm = bytes[offset++];

    // Record ID
    final recordIdLen = bytes[offset++];
    final recordId = utf8.decode(bytes.sublist(offset, offset + recordIdLen));
    offset += recordIdLen;

    // Patient Ref
    final patientRefLen = bytes[offset++];
    final patientRef = utf8.decode(bytes.sublist(offset, offset + patientRefLen));
    offset += patientRefLen;

    // Nonce (12 bytes)
    final nonce = Uint8List.sublistView(bytes, offset, offset + HrxConstants.nonceLength);
    offset += HrxConstants.nonceLength;

    // Payload length (2 bytes)
    final payloadLen = ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.big);
    offset += 2;

    if (offset + payloadLen > contentLen) {
      throw HrxException(
        code: HrxErrorCode.invalidPacket,
        message: 'Malformed packet: payload length mismatch.',
      );
    }

    final payload = Uint8List.sublistView(bytes, offset, offset + payloadLen);

    return HrxPacket(
      protocolVersion: protocolVersion,
      packetType: packetType,
      schemaVersion: schemaVersion,
      keyId: keyId,
      compressionAlgorithm: compressionAlgorithm,
      encryptionAlgorithm: encryptionAlgorithm,
      recordId: recordId,
      patientRef: patientRef,
      nonce: nonce,
      payload: payload,
      signature: expectedSignature,
    );
  }
}
