/// Health Record Exchange (HRX) Protocol Library.
/// Offline medical QR system specification v1.

// Protocol & Constants
export 'src/protocol/constants.dart';
export 'src/protocol/errors.dart';
export 'src/protocol/capacity.dart';
export 'src/protocol/hrx_packet.dart';

// Data Models
export 'src/models/patient_record.dart';
export 'src/models/visit_record.dart';

// Crypto & Security
export 'src/crypto/sha256_hmac.dart';
export 'src/crypto/aes_gcm.dart';
export 'src/crypto/key_provider.dart';

// Compression & Serialization
export 'src/compression/deflate_compressor.dart';
export 'src/serialization/cbor_codec.dart';
export 'src/serialization/base45.dart';

// Encoder & Decoder Engines
export 'src/encoder/hrx_encoder.dart';
export 'src/decoder/hrx_decoder.dart';

// Repositories
export 'src/repositories/patient_repository.dart';
export 'src/repositories/visit_repository.dart';

// UI & Scannable QR Rendering
export 'src/ui/hrx_qr_widget.dart';
