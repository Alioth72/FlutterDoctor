import 'dart:math';
import 'dart:typed_data';
import '../protocol/errors.dart';
import 'sha256_hmac.dart';

/// Pure Dart implementation of AES-256 in Galois/Counter Mode (AES-256-GCM)
/// complying with NIST SP 800-38D.
class HrxAesGcm {
  HrxAesGcm._();

  static const List<int> _sbox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36,
  ];

  static Uint32List _expandKey(Uint8List key) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte (256-bit) key.');
    }
    final w = Uint32List(60);
    final bd = ByteData.sublistView(key);
    for (int i = 0; i < 8; i++) {
      w[i] = bd.getUint32(i * 4, Endian.big);
    }

    for (int i = 8; i < 60; i++) {
      int temp = w[i - 1];
      if (i % 8 == 0) {
        temp = ((_sbox[(temp >>> 16) & 0xFF] << 24) |
                (_sbox[(temp >>> 8) & 0xFF] << 16) |
                (_sbox[temp & 0xFF] << 8) |
                _sbox[(temp >>> 24) & 0xFF]) ^
            (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = (_sbox[(temp >>> 24) & 0xFF] << 24) |
            (_sbox[(temp >>> 16) & 0xFF] << 16) |
            (_sbox[(temp >>> 8) & 0xFF] << 8) |
            _sbox[temp & 0xFF];
      }
      w[i] = w[i - 8] ^ temp;
    }
    return w;
  }

  static int _xtimes(int b) => ((b << 1) ^ (((b >>> 7) & 1) * 0x11b)) & 0xFF;

  static void _encryptBlock(Uint32List roundKeys, Uint8List block, int offset) {
    var s0 = block[offset];
    var s1 = block[offset + 1];
    var s2 = block[offset + 2];
    var s3 = block[offset + 3];
    var s4 = block[offset + 4];
    var s5 = block[offset + 5];
    var s6 = block[offset + 6];
    var s7 = block[offset + 7];
    var s8 = block[offset + 8];
    var s9 = block[offset + 9];
    var s10 = block[offset + 10];
    var s11 = block[offset + 11];
    var s12 = block[offset + 12];
    var s13 = block[offset + 13];
    var s14 = block[offset + 14];
    var s15 = block[offset + 15];

    // AddRoundKey 0
    s0 ^= (roundKeys[0] >>> 24) & 0xFF;
    s1 ^= (roundKeys[0] >>> 16) & 0xFF;
    s2 ^= (roundKeys[0] >>> 8) & 0xFF;
    s3 ^= roundKeys[0] & 0xFF;
    s4 ^= (roundKeys[1] >>> 24) & 0xFF;
    s5 ^= (roundKeys[1] >>> 16) & 0xFF;
    s6 ^= (roundKeys[1] >>> 8) & 0xFF;
    s7 ^= roundKeys[1] & 0xFF;
    s8 ^= (roundKeys[2] >>> 24) & 0xFF;
    s9 ^= (roundKeys[2] >>> 16) & 0xFF;
    s10 ^= (roundKeys[2] >>> 8) & 0xFF;
    s11 ^= roundKeys[2] & 0xFF;
    s12 ^= (roundKeys[3] >>> 24) & 0xFF;
    s13 ^= (roundKeys[3] >>> 16) & 0xFF;
    s14 ^= (roundKeys[3] >>> 8) & 0xFF;
    s15 ^= roundKeys[3] & 0xFF;

    for (int round = 1; round < 14; round++) {
      // SubBytes & ShiftRows
      final t0 = _sbox[s0];
      final t1 = _sbox[s5];
      final t2 = _sbox[s10];
      final t3 = _sbox[s15];

      final t4 = _sbox[s4];
      final t5 = _sbox[s9];
      final t6 = _sbox[s14];
      final t7 = _sbox[s3];

      final t8 = _sbox[s8];
      final t9 = _sbox[s13];
      final t10 = _sbox[s2];
      final t11 = _sbox[s7];

      final t12 = _sbox[s12];
      final t13 = _sbox[s1];
      final t14 = _sbox[s6];
      final t15 = _sbox[s11];

      // MixColumns + AddRoundKey
      final rk0 = roundKeys[round * 4];
      final rk1 = roundKeys[round * 4 + 1];
      final rk2 = roundKeys[round * 4 + 2];
      final rk3 = roundKeys[round * 4 + 3];

      s0 = _xtimes(t0 ^ t1) ^ t1 ^ t2 ^ t3 ^ ((rk0 >>> 24) & 0xFF);
      s1 = _xtimes(t1 ^ t2) ^ t2 ^ t3 ^ t0 ^ ((rk0 >>> 16) & 0xFF);
      s2 = _xtimes(t2 ^ t3) ^ t3 ^ t0 ^ t1 ^ ((rk0 >>> 8) & 0xFF);
      s3 = _xtimes(t3 ^ t0) ^ t0 ^ t1 ^ t2 ^ (rk0 & 0xFF);

      s4 = _xtimes(t4 ^ t5) ^ t5 ^ t6 ^ t7 ^ ((rk1 >>> 24) & 0xFF);
      s5 = _xtimes(t5 ^ t6) ^ t6 ^ t7 ^ t4 ^ ((rk1 >>> 16) & 0xFF);
      s6 = _xtimes(t6 ^ t7) ^ t7 ^ t4 ^ t5 ^ ((rk1 >>> 8) & 0xFF);
      s7 = _xtimes(t7 ^ t4) ^ t4 ^ t5 ^ t6 ^ (rk1 & 0xFF);

      s8 = _xtimes(t8 ^ t9) ^ t9 ^ t10 ^ t11 ^ ((rk2 >>> 24) & 0xFF);
      s9 = _xtimes(t9 ^ t10) ^ t10 ^ t11 ^ t8 ^ ((rk2 >>> 16) & 0xFF);
      s10 = _xtimes(t10 ^ t11) ^ t11 ^ t8 ^ t9 ^ ((rk2 >>> 8) & 0xFF);
      s11 = _xtimes(t11 ^ t8) ^ t8 ^ t9 ^ t10 ^ (rk2 & 0xFF);

      s12 = _xtimes(t12 ^ t13) ^ t13 ^ t14 ^ t15 ^ ((rk3 >>> 24) & 0xFF);
      s13 = _xtimes(t13 ^ t14) ^ t14 ^ t15 ^ t12 ^ ((rk3 >>> 16) & 0xFF);
      s14 = _xtimes(t14 ^ t15) ^ t15 ^ t12 ^ t13 ^ ((rk3 >>> 8) & 0xFF);
      s15 = _xtimes(t15 ^ t12) ^ t12 ^ t13 ^ t14 ^ (rk3 & 0xFF);
    }

    // Round 14: SubBytes, ShiftRows, AddRoundKey (No MixColumns)
    final rk0 = roundKeys[56];
    final rk1 = roundKeys[57];
    final rk2 = roundKeys[58];
    final rk3 = roundKeys[59];

    block[offset] = _sbox[s0] ^ ((rk0 >>> 24) & 0xFF);
    block[offset + 1] = _sbox[s5] ^ ((rk0 >>> 16) & 0xFF);
    block[offset + 2] = _sbox[s10] ^ ((rk0 >>> 8) & 0xFF);
    block[offset + 3] = _sbox[s15] ^ (rk0 & 0xFF);

    block[offset + 4] = _sbox[s4] ^ ((rk1 >>> 24) & 0xFF);
    block[offset + 5] = _sbox[s9] ^ ((rk1 >>> 16) & 0xFF);
    block[offset + 6] = _sbox[s14] ^ ((rk1 >>> 8) & 0xFF);
    block[offset + 7] = _sbox[s3] ^ (rk1 & 0xFF);

    block[offset + 8] = _sbox[s8] ^ ((rk2 >>> 24) & 0xFF);
    block[offset + 9] = _sbox[s13] ^ ((rk2 >>> 16) & 0xFF);
    block[offset + 10] = _sbox[s2] ^ ((rk2 >>> 8) & 0xFF);
    block[offset + 11] = _sbox[s7] ^ (rk2 & 0xFF);

    block[offset + 12] = _sbox[s12] ^ ((rk3 >>> 24) & 0xFF);
    block[offset + 13] = _sbox[s1] ^ ((rk3 >>> 16) & 0xFF);
    block[offset + 14] = _sbox[s6] ^ ((rk3 >>> 8) & 0xFF);
    block[offset + 15] = _sbox[s11] ^ (rk3 & 0xFF);
  }

  /// GHASH multiplication in GF(2^128)
  static void _gfMultiply(Uint8List x, Uint8List y) {
    final z = Uint8List(16);
    final v = Uint8List.fromList(y);

    for (int i = 0; i < 128; i++) {
      final bytePos = i ~/ 8;
      final bitPos = 7 - (i % 8);
      if ((x[bytePos] & (1 << bitPos)) != 0) {
        for (int j = 0; j < 16; j++) {
          z[j] ^= v[j];
        }
      }
      final lsb = v[15] & 1;
      for (int j = 15; j > 0; j--) {
        v[j] = ((v[j] >>> 1) | ((v[j - 1] & 1) << 7)) & 0xFF;
      }
      v[0] = (v[0] >>> 1) & 0xFF;
      if (lsb != 0) {
        v[0] ^= 0xe1;
      }
    }
    x.setRange(0, 16, z);
  }

  static Uint8List _ghash(Uint8List h, Uint8List aad, Uint8List ciphertext) {
    final x = Uint8List(16);

    void processBlocks(Uint8List data) {
      for (int i = 0; i < data.length; i += 16) {
        final block = Uint8List(16);
        final len = min(16, data.length - i);
        block.setRange(0, len, data, i);
        for (int j = 0; j < 16; j++) {
          x[j] ^= block[j];
        }
        _gfMultiply(x, h);
      }
    }

    processBlocks(aad);
    processBlocks(ciphertext);

    final lenBlock = Uint8List(16);
    final bd = ByteData.sublistView(lenBlock);
    bd.setUint64(0, aad.length * 8, Endian.big);
    bd.setUint64(8, ciphertext.length * 8, Endian.big);

    for (int j = 0; j < 16; j++) {
      x[j] ^= lenBlock[j];
    }
    _gfMultiply(x, h);
    return x;
  }

  /// Encrypts plaintext using AES-256-GCM.
  /// Returns [ciphertext || authTag] (length = plaintext.length + 16).
  static Uint8List encrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
    Uint8List? associatedData,
  }) {
    if (key.length != 32) throw ArgumentError('Key must be 32 bytes.');
    if (nonce.length != 12) throw ArgumentError('Nonce must be 12 bytes.');

    final roundKeys = _expandKey(key);
    final h = Uint8List(16);
    _encryptBlock(roundKeys, h, 0);

    // Initial counter block J0
    final j0 = Uint8List(16);
    j0.setRange(0, 12, nonce);
    j0[15] = 1;

    // Encrypt plaintext in CTR mode
    final ciphertext = Uint8List(plaintext.length);
    final counter = Uint8List.fromList(j0);
    int ctrVal = 1;

    for (int offset = 0; offset < plaintext.length; offset += 16) {
      ctrVal++;
      counter[12] = (ctrVal >>> 24) & 0xFF;
      counter[13] = (ctrVal >>> 16) & 0xFF;
      counter[14] = (ctrVal >>> 8) & 0xFF;
      counter[15] = ctrVal & 0xFF;

      final keystream = Uint8List.fromList(counter);
      _encryptBlock(roundKeys, keystream, 0);

      final blockSize = min(16, plaintext.length - offset);
      for (int i = 0; i < blockSize; i++) {
        ciphertext[offset + i] = plaintext[offset + i] ^ keystream[i];
      }
    }

    final s = _ghash(h, associatedData ?? Uint8List(0), ciphertext);
    final ej0 = Uint8List.fromList(j0);
    _encryptBlock(roundKeys, ej0, 0);

    final tag = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      tag[i] = s[i] ^ ej0[i];
    }

    final result = Uint8List(ciphertext.length + 16);
    result.setRange(0, ciphertext.length, ciphertext);
    result.setRange(ciphertext.length, result.length, tag);
    return result;
  }

  /// Decrypts ciphertext and verifies GCM authentication tag.
  /// Input is [ciphertext || 16-byte authTag].
  /// Throws [HrxException] if tag verification fails or data is corrupted.
  static Uint8List decrypt({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertextWithTag,
    Uint8List? associatedData,
  }) {
    if (key.length != 32) throw ArgumentError('Key must be 32 bytes.');
    if (nonce.length != 12) throw ArgumentError('Nonce must be 12 bytes.');
    if (ciphertextWithTag.length < 16) {
      throw HrxException(
        code: HrxErrorCode.decryptionFailure,
        message: 'Payload is too short to contain AES-GCM authentication tag.',
      );
    }

    final cipherLen = ciphertextWithTag.length - 16;
    final ciphertext = Uint8List.sublistView(ciphertextWithTag, 0, cipherLen);
    final expectedTag = Uint8List.sublistView(ciphertextWithTag, cipherLen);

    final roundKeys = _expandKey(key);
    final h = Uint8List(16);
    _encryptBlock(roundKeys, h, 0);

    final j0 = Uint8List(16);
    j0.setRange(0, 12, nonce);
    j0[15] = 1;

    final s = _ghash(h, associatedData ?? Uint8List(0), ciphertext);
    final ej0 = Uint8List.fromList(j0);
    _encryptBlock(roundKeys, ej0, 0);

    final computedTag = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      computedTag[i] = s[i] ^ ej0[i];
    }

    if (!HrxSha256.constantTimeEquals(computedTag, expectedTag)) {
      throw HrxException(
        code: HrxErrorCode.integrityFailure,
        message: 'AES-GCM authentication tag verification failed. Data corrupted or modified.',
      );
    }

    // Decrypt in CTR mode
    final plaintext = Uint8List(cipherLen);
    final counter = Uint8List.fromList(j0);
    int ctrVal = 1;

    for (int offset = 0; offset < cipherLen; offset += 16) {
      ctrVal++;
      counter[12] = (ctrVal >>> 24) & 0xFF;
      counter[13] = (ctrVal >>> 16) & 0xFF;
      counter[14] = (ctrVal >>> 8) & 0xFF;
      counter[15] = ctrVal & 0xFF;

      final keystream = Uint8List.fromList(counter);
      _encryptBlock(roundKeys, keystream, 0);

      final blockSize = min(16, cipherLen - offset);
      for (int i = 0; i < blockSize; i++) {
        plaintext[offset + i] = ciphertext[offset + i] ^ keystream[i];
      }
    }

    return plaintext;
  }

  /// Generates a cryptographically random 12-byte (96-bit) nonce
  static Uint8List generateRandomNonce() {
    final rng = Random.secure();
    final nonce = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonce[i] = rng.nextInt(256);
    }
    return nonce;
  }
}
