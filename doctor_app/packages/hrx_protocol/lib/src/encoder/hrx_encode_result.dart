class HrxEncodeResult {
  final String qrPayload;
  final int qrVersion;
  final int originalSize;
  final int compressedSize;
  final String compressionAlgorithm;
  final int finalPayloadSize;
  final String payloadEncoding;
  final double compressionRatio;

  HrxEncodeResult({
    required this.qrPayload,
    required this.qrVersion,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionAlgorithm,
    required this.finalPayloadSize,
    required this.payloadEncoding,
    required this.compressionRatio,
  });
}
