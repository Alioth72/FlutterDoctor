import 'dart:typed_data';

/// Pure Dart implementation of standard SHA-256 (FIPS PUB 180-4)
/// and HMAC-SHA-256 (RFC 2104).
class HrxSha256 {
  HrxSha256._();

  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;

  static Uint8List hash(Uint8List data) {
    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final bitLen = data.length * 8;
    final padLen = (data.length % 64 < 56)
        ? (56 - (data.length % 64))
        : (120 - (data.length % 64));

    final padded = Uint8List(data.length + padLen + 8);
    padded.setRange(0, data.length, data);
    padded[data.length] = 0x80;

    final bd = ByteData.sublistView(padded);
    bd.setUint32(padded.length - 4, bitLen & 0xFFFFFFFF, Endian.big);
    bd.setUint32(padded.length - 8, (bitLen ~/ 0x100000000) & 0xFFFFFFFF, Endian.big);

    final w = Int32List(64);

    for (int offset = 0; offset < padded.length; offset += 64) {
      for (int i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + (i * 4), Endian.big);
      }
      for (int i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0, b = h1, c = h2, d = h3;
      int e = h4, f = h5, g = h6, h = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = (h + s1 + ch + _k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final result = Uint8List(32);
    final rbd = ByteData.sublistView(result);
    rbd.setUint32(0, h0, Endian.big);
    rbd.setUint32(4, h1, Endian.big);
    rbd.setUint32(8, h2, Endian.big);
    rbd.setUint32(12, h3, Endian.big);
    rbd.setUint32(16, h4, Endian.big);
    rbd.setUint32(20, h5, Endian.big);
    rbd.setUint32(24, h6, Endian.big);
    rbd.setUint32(28, h7, Endian.big);
    return result;
  }

  /// Computes HMAC-SHA256
  static Uint8List hmac(Uint8List key, Uint8List message) {
    Uint8List k = key;
    if (k.length > 64) {
      k = hash(k);
    }
    final keyPad = Uint8List(64);
    keyPad.setRange(0, k.length, k);

    final ipad = Uint8List(64);
    final opad = Uint8List(64);
    for (int i = 0; i < 64; i++) {
      ipad[i] = keyPad[i] ^ 0x36;
      opad[i] = keyPad[i] ^ 0x5C;
    }

    final inner = Uint8List(64 + message.length);
    inner.setRange(0, 64, ipad);
    inner.setRange(64, inner.length, message);
    final innerHash = hash(inner);

    final outer = Uint8List(64 + 32);
    outer.setRange(0, 64, opad);
    outer.setRange(64, outer.length, innerHash);
    return hash(outer);
  }

  /// Constant-time comparison to prevent timing attacks
  static bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
