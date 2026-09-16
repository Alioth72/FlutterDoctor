import 'dart:typed_data';

/// RFC 9285 Base45 encoder and decoder for QR-native alphanumeric compaction.
class Base45 {
  Base45._();

  static const String _charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ \$%*+-./:';

  static final Map<int, int> _decodeMap = () {
    final map = <int, int>{};
    for (int i = 0; i < _charset.length; i++) {
      map[_charset.codeUnitAt(i)] = i;
    }
    return map;
  }();

  /// Encodes [bytes] into a Base45 string.
  static String encode(List<int> bytes) {
    if (bytes.isEmpty) return '';
    final buffer = StringBuffer();
    final len = bytes.length;

    for (int i = 0; i < len; i += 2) {
      if (i + 1 < len) {
        final val = (bytes[i] << 8) | bytes[i + 1];
        final c = val % 45;
        final d = (val ~/ 45) % 45;
        final e = (val ~/ 2025) % 45;
        buffer.write(_charset[c]);
        buffer.write(_charset[d]);
        buffer.write(_charset[e]);
      } else {
        final val = bytes[i];
        final c = val % 45;
        final d = val ~/ 45;
        buffer.write(_charset[c]);
        buffer.write(_charset[d]);
      }
    }
    return buffer.toString();
  }

  /// Decodes [input] Base45 string into [Uint8List].
  static Uint8List decode(String input) {
    if (input.isEmpty) return Uint8List(0);
    final trimmed = input.trim();
    final bytes = <int>[];
    final len = trimmed.length;

    int i = 0;
    while (i < len) {
      final remaining = len - i;
      if (remaining >= 3) {
        final c0 = _decodeMap[trimmed.codeUnitAt(i)];
        final c1 = _decodeMap[trimmed.codeUnitAt(i + 1)];
        final c2 = _decodeMap[trimmed.codeUnitAt(i + 2)];

        if (c0 == null || c1 == null || c2 == null) {
          throw FormatException('Invalid Base45 character at index $i: ${trimmed.substring(i, i + 3)}');
        }

        final val = c0 + (c1 * 45) + (c2 * 2025);
        if (val > 65535) {
          throw FormatException('Base45 value overflow at index $i: $val');
        }

        bytes.add((val >> 8) & 0xFF);
        bytes.add(val & 0xFF);
        i += 3;
      } else if (remaining == 2) {
        final c0 = _decodeMap[trimmed.codeUnitAt(i)];
        final c1 = _decodeMap[trimmed.codeUnitAt(i + 1)];

        if (c0 == null || c1 == null) {
          throw FormatException('Invalid Base45 character at index $i: ${trimmed.substring(i, i + 2)}');
        }

        final val = c0 + (c1 * 45);
        if (val > 255) {
          throw FormatException('Base45 value overflow at index $i: $val');
        }

        bytes.add(val & 0xFF);
        i += 2;
      } else {
        throw const FormatException('Invalid Base45 string length: cannot have 1 trailing character.');
      }
    }

    return Uint8List.fromList(bytes);
  }
}
