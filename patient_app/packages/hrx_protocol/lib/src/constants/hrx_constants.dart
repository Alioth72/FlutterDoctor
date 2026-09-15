class HrxConstants {
  static const String protocol = 'HRX';
  static const int version = 1;
  static const String typePatient = 'PATIENT';
  static const String typeVisit = 'VISIT';

  // QR String Prefixes
  static const String qrPrefixPatient = 'HRX:P:';
  static const String qrPrefixCompressedVisit = 'HRX:Z:';
  static const String qrPrefixVisit = 'HRX:V:';
  static const String qrPrefixEncrypted = 'HRX:E:';

  // Compression algorithms
  static const String algoDeflate = 'Deflate';
  static const String algoNone = 'None';

  // Encodings
  static const String encBase64Url = 'Base64URL';
}
