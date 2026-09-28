import 'dart:typed_data';
import '../protocol/errors.dart';
import 'sha256_hmac.dart';

/// Abstract Key Provider interface for HRX encryption and integrity signing keys.
abstract class HrxKeyProvider {
  /// Retrieves a 32-byte AES-256 encryption key for the given key ID
  Uint8List getEncryptionKey(int keyId);

  /// Retrieves a 32-byte HMAC-SHA256 signing key for the given key ID
  Uint8List getSigningKey(int keyId);
}

/// Development Key Provider for Phase 1 offline medical record exchange.
/// Uses deterministic key derivation from local seed tokens (DEVELOPMENT ONLY).
class DevKeyProvider implements HrxKeyProvider {
  static final DevKeyProvider instance = DevKeyProvider._internal();
  DevKeyProvider._internal();

  // Local development seed tokens (For Phase 1 local demo only)
  static final Uint8List _devEncSeed = Uint8List.fromList([
    0x48, 0x52, 0x58, 0x2D, 0x4B, 0x45, 0x59, 0x2D,
    0x45, 0x4E, 0x43, 0x2D, 0x50, 0x48, 0x41, 0x53,
    0x45, 0x31, 0x2D, 0x53, 0x45, 0x43, 0x55, 0x52,
    0x45, 0x2D, 0x44, 0x45, 0x56, 0x2D, 0x30, 0x31,
  ]);

  static final Uint8List _devSignSeed = Uint8List.fromList([
    0x48, 0x52, 0x58, 0x2D, 0x4B, 0x45, 0x59, 0x2D,
    0x53, 0x49, 0x47, 0x4E, 0x2D, 0x50, 0x48, 0x41,
    0x53, 0x45, 0x31, 0x2D, 0x53, 0x45, 0x43, 0x55,
    0x52, 0x45, 0x2D, 0x44, 0x45, 0x56, 0x30, 0x32,
  ]);

  @override
  Uint8List getEncryptionKey(int keyId) {
    if (keyId != 1 && keyId != 0x01) {
      throw HrxException(
        code: HrxErrorCode.unknownKey,
        message: 'Unknown key ID $keyId. Development provider supports key ID 1.',
      );
    }
    // Deterministic 32-byte derived key
    return HrxSha256.hash(_devEncSeed);
  }

  @override
  Uint8List getSigningKey(int keyId) {
    if (keyId != 1 && keyId != 0x01) {
      throw HrxException(
        code: HrxErrorCode.unknownKey,
        message: 'Unknown key ID $keyId. Development provider supports key ID 1.',
      );
    }
    // Deterministic 32-byte derived signing key
    return HrxSha256.hash(_devSignSeed);
  }
}

/// Production Key Provider stub for future enterprise backend/KMS key exchange.
class ProductionKeyProvider implements HrxKeyProvider {
  @override
  Uint8List getEncryptionKey(int keyId) {
    throw UnimplementedError('Production KMS key management is not configured in Phase 1.');
  }

  @override
  Uint8List getSigningKey(int keyId) {
    throw UnimplementedError('Production KMS key management is not configured in Phase 1.');
  }
}
