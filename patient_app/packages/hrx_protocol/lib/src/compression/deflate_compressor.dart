import 'dart:io';
import 'dart:typed_data';
import '../protocol/errors.dart';

/// Deflate compression and decompression for HRX payloads.
class HrxDeflateCompressor {
  HrxDeflateCompressor._();

  static final ZLibCodec _rawZLib = ZLibCodec(raw: true);

  /// Compresses [data] using Deflate.
  static Uint8List compress(Uint8List data) {
    try {
      final compressed = _rawZLib.encode(data);
      return Uint8List.fromList(compressed);
    } catch (e) {
      throw HrxException(
        code: HrxErrorCode.decompressionFailure,
        message: 'Compression failed: $e',
      );
    }
  }

  /// Decompresses [compressedData] using Deflate with multi-tier fallback (raw deflate, zlib, gzip, or plain utf8).
  static Uint8List decompress(Uint8List compressedData) {
    // Stage 1: Try Raw Deflate (RFC 1951, standard HRX format)
    try {
      final decompressed = _rawZLib.decode(compressedData);
      return Uint8List.fromList(decompressed);
    } catch (_) {
      // Continue to next stage
    }

    // Stage 2: Try Standard ZLib (RFC 1950, with headers)
    try {
      final decompressed = zlib.decode(compressedData);
      return Uint8List.fromList(decompressed);
    } catch (_) {
      // Continue to next stage
    }

    // Stage 3: Try GZip (RFC 1952)
    try {
      final decompressed = gzip.decode(compressedData);
      return Uint8List.fromList(decompressed);
    } catch (_) {
      // Continue to next stage
    }

    // Stage 4: Check if already plain UTF-8 text (e.g. JSON map/array)
    try {
      if (compressedData.isNotEmpty) {
        final firstChar = compressedData.first;
        // 0x7B = '{', 0x5B = '[', 0x20 = ' ', 0x0A = '\n', 0x0D = '\r', 0x09 = '\t'
        if (firstChar == 0x7B || firstChar == 0x5B || firstChar <= 0x20) {
          return compressedData;
        }
      }
    } catch (_) {}

    throw HrxException(
      code: HrxErrorCode.decompressionFailure,
      message: 'Decompression failed: unsupported or corrupted payload format.',
    );
  }
}
