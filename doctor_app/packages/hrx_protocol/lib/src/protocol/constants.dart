import 'dart:typed_data';

/// Health Record Exchange (HRX) Protocol Constants - Specification v1.
class HrxConstants {
  HrxConstants._();

  /// Magic 3-byte ASCII identifier for HRX packets: 'H', 'R', 'X'
  static const String magicString = 'HRX';
  static final Uint8List magicBytes = Uint8List.fromList([0x48, 0x52, 0x58]);

  /// Protocol version
  static const int protocolVersion = 1;

  /// Schema version for medical records
  static const int schemaVersion = 1;

  /// Packet types
  static const int packetTypePatient = 0x01;
  static const int packetTypeVisit = 0x02;

  /// Compression algorithms
  static const int compressionNone = 0x00;
  static const int compressionDeflate = 0x01;

  /// Encryption algorithms
  static const int encryptionNone = 0x00;
  static const int encryptionAes256Gcm = 0x01;

  /// Development default Key ID
  static const int defaultKeyId = 0x01;

  /// Default Nonce length for AES-GCM (12 bytes / 96 bits)
  static const int nonceLength = 12;

  /// Auth tag length for AES-GCM (16 bytes / 128 bits)
  static const int gcmTagLength = 16;

  /// HMAC-SHA256 signature length (32 bytes / 256 bits)
  static const int signatureLength = 32;

  /// Maximum binary payload bytes that fit safely into a single QR Code
  /// Version 40 with Error Correction M has an alphanumeric limit of 3,853 chars
  /// and binary limit of 2,331 bytes.
  static const int maxQrByteCapacity = 2331;

  /// Standard prefix for base64 encoded HRX QR payloads
  static const String qrPrefix = 'HRX:';

  /// Prefix for Base45 encoded HRX QR payloads (RFC 9285)
  static const String qrPrefixBase45 = 'HRX:45:';

  /// Prefix for compact pipe-delimited Patient Identity QR payloads
  static const String qrPrefixPatient = 'HRX:P|';

  /// Prefix for built-in Deflate-compressed Base64Url Visit QR payloads
  static const String qrPrefixCompressedVisit = 'HRX:Z:';

  /// Standard error correction level
  static const String errorCorrectionLevel = 'M';
}
