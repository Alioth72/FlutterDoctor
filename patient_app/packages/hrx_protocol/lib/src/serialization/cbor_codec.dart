import 'dart:convert';
import 'dart:typed_data';
import '../protocol/errors.dart';

/// Pure Dart CBOR (RFC 7049) encoder and decoder for compact binary serialization.
class HrxCborCodec {
  HrxCborCodec._();

  /// Encodes dynamic Dart object (Map, List, num, String, bool, null, Uint8List) to CBOR bytes.
  static Uint8List encode(dynamic object) {
    final builder = BytesBuilder();
    _encodeValue(object, builder);
    return builder.toBytes();
  }

  /// Decodes CBOR bytes back to Dart object (Map, List, num, String, bool, null).
  static dynamic decode(Uint8List bytes) {
    final reader = _CborReader(bytes);
    final value = reader.readValue();
    return value;
  }

  static void _encodeHeader(int majorType, int value, BytesBuilder builder) {
    final mt = (majorType & 0x07) << 5;
    if (value < 24) {
      builder.addByte(mt | value);
    } else if (value <= 0xFF) {
      builder.addByte(mt | 24);
      builder.addByte(value);
    } else if (value <= 0xFFFF) {
      builder.addByte(mt | 25);
      builder.add([ (value >> 8) & 0xFF, value & 0xFF ]);
    } else if (value <= 0xFFFFFFFF) {
      builder.addByte(mt | 26);
      builder.add([
        (value >> 24) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
      ]);
    } else {
      builder.addByte(mt | 27);
      final bd = ByteData(8);
      bd.setUint64(0, value, Endian.big);
      builder.add(bd.buffer.asUint8List());
    }
  }

  static void _encodeValue(dynamic value, BytesBuilder builder) {
    if (value == null) {
      builder.addByte(0xF6); // Major 7, simple 22 (null)
    } else if (value is bool) {
      builder.addByte(value ? 0xF5 : 0xF4); // Major 7, 21 (true) / 20 (false)
    } else if (value is int) {
      if (value >= 0) {
        _encodeHeader(0, value, builder);
      } else {
        _encodeHeader(1, -1 - value, builder);
      }
    } else if (value is double) {
      builder.addByte(0xFB); // Major 7, 27 (float64)
      final bd = ByteData(8);
      bd.setFloat64(0, value, Endian.big);
      builder.add(bd.buffer.asUint8List());
    } else if (value is String) {
      final utf8Bytes = utf8.encode(value);
      _encodeHeader(3, utf8Bytes.length, builder);
      builder.add(utf8Bytes);
    } else if (value is Uint8List) {
      _encodeHeader(2, value.length, builder);
      builder.add(value);
    } else if (value is List) {
      _encodeHeader(4, value.length, builder);
      for (final item in value) {
        _encodeValue(item, builder);
      }
    } else if (value is Map) {
      _encodeHeader(5, value.length, builder);
      value.forEach((k, v) {
        _encodeValue(k.toString(), builder);
        _encodeValue(v, builder);
      });
    } else {
      // Fallback: encode as String
      final str = value.toString();
      final utf8Bytes = utf8.encode(str);
      _encodeHeader(3, utf8Bytes.length, builder);
      builder.add(utf8Bytes);
    }
  }
}

class _CborReader {
  final Uint8List _bytes;
  int _offset = 0;

  _CborReader(this._bytes);

  int get remaining => _bytes.length - _offset;

  dynamic readValue() {
    if (_offset >= _bytes.length) {
      throw HrxException(
        code: HrxErrorCode.deserializationFailure,
        message: 'Unexpected end of CBOR payload at byte $_offset',
      );
    }

    final initialByte = _bytes[_offset++];
    final majorType = (initialByte >> 5) & 0x07;
    final additionalInfo = initialByte & 0x1F;

    int readLength() {
      if (additionalInfo < 24) {
        return additionalInfo;
      } else if (additionalInfo == 24) {
        return _bytes[_offset++];
      } else if (additionalInfo == 25) {
        final val = ByteData.sublistView(_bytes, _offset, _offset + 2).getUint16(0, Endian.big);
        _offset += 2;
        return val;
      } else if (additionalInfo == 26) {
        final val = ByteData.sublistView(_bytes, _offset, _offset + 4).getUint32(0, Endian.big);
        _offset += 4;
        return val;
      } else if (additionalInfo == 27) {
        final val = ByteData.sublistView(_bytes, _offset, _offset + 8).getUint64(0, Endian.big);
        _offset += 8;
        return val;
      } else {
        throw HrxException(
          code: HrxErrorCode.deserializationFailure,
          message: 'Unsupported CBOR additional info $additionalInfo',
        );
      }
    }

    switch (majorType) {
      case 0: // unsigned int
        return readLength();
      case 1: // negative int
        return -1 - readLength();
      case 2: // byte string
        final len = readLength();
        final bytes = Uint8List.sublistView(_bytes, _offset, _offset + len);
        _offset += len;
        return bytes;
      case 3: // UTF-8 text string
        final len = readLength();
        final strBytes = Uint8List.sublistView(_bytes, _offset, _offset + len);
        _offset += len;
        return utf8.decode(strBytes);
      case 4: // Array
        final count = readLength();
        final list = <dynamic>[];
        for (int i = 0; i < count; i++) {
          list.add(readValue());
        }
        return list;
      case 5: // Map
        final count = readLength();
        final map = <String, dynamic>{};
        for (int i = 0; i < count; i++) {
          final key = readValue().toString();
          final val = readValue();
          map[key] = val;
        }
        return map;
      case 7: // Simple / Float
        if (additionalInfo == 20) return false;
        if (additionalInfo == 21) return true;
        if (additionalInfo == 22) return null;
        if (additionalInfo == 27) {
          final val = ByteData.sublistView(_bytes, _offset, _offset + 8).getFloat64(0, Endian.big);
          _offset += 8;
          return val;
        }
        return null;
      default:
        throw HrxException(
          code: HrxErrorCode.deserializationFailure,
          message: 'Unsupported CBOR major type $majorType',
        );
    }
  }
}
