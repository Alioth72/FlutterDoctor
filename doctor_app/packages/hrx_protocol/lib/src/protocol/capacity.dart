import 'constants.dart';

enum HrxCapacityStatus {
  fits,
  tooLarge,
}

class HrxCapacityResult {
  final HrxCapacityStatus status;
  final int byteLength;
  final int maxCapacity;
  final int estimatedQrVersion;
  final double capacityUsedPercentage;

  const HrxCapacityResult({
    required this.status,
    required this.byteLength,
    required this.maxCapacity,
    required this.estimatedQrVersion,
    required this.capacityUsedPercentage,
  });

  bool get isFits => status == HrxCapacityStatus.fits;
  bool get isTooLarge => status == HrxCapacityStatus.tooLarge;

  @override
  String toString() =>
      'HrxCapacityResult(status: $status, $byteLength / $maxCapacity bytes (${capacityUsedPercentage.toStringAsFixed(1)}%), QR v$estimatedQrVersion)';
}

class HrxCapacityChecker {
  HrxCapacityChecker._();

  /// Approximate maximum binary bytes for QR Versions 1 to 40 at Error Correction M.
  /// Standard ISO/IEC 18004 capacity table.
  static const List<int> _versionCapacitiesM = [
    14, 26, 42, 62, 84, 106, 122, 152, 180, 213, // v1 - v10
    251, 287, 331, 362, 412, 450, 504, 560, 624, 666, // v11 - v20
    711, 779, 857, 911, 997, 1059, 1125, 1190, 1286, 1370, // v21 - v30
    1452, 1538, 1628, 1722, 1809, 1911, 1989, 2099, 2213, 2331, // v31 - v40
  ];

  /// Checks if the payload fits inside QR Version 40 (level M)
  static HrxCapacityResult checkCapacity(int payloadBytes) {
    final maxCap = HrxConstants.maxQrByteCapacity;
    if (payloadBytes > maxCap) {
      return HrxCapacityResult(
        status: HrxCapacityStatus.tooLarge,
        byteLength: payloadBytes,
        maxCapacity: maxCap,
        estimatedQrVersion: 40,
        capacityUsedPercentage: (payloadBytes / maxCap) * 100.0,
      );
    }

    int version = 40;
    for (int i = 0; i < _versionCapacitiesM.length; i++) {
      if (payloadBytes <= _versionCapacitiesM[i]) {
        version = i + 1;
        break;
      }
    }

    return HrxCapacityResult(
      status: HrxCapacityStatus.fits,
      byteLength: payloadBytes,
      maxCapacity: maxCap,
      estimatedQrVersion: version,
      capacityUsedPercentage: (payloadBytes / maxCap) * 100.0,
    );
  }
}
