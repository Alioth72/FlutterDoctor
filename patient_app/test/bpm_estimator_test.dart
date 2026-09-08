import 'dart:math' as math;

import 'package:patient_app/services/bpm_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recovers BPM from an irregularly timed periodic BVP signal', () {
    final estimator = TimingAwareBpmEstimator();
    final start = DateTime(2026, 1, 1);
    var elapsedMicros = 0;
    BpmEstimate? latest;

    for (var index = 0; elapsedMicros < 32 * 1000000; index++) {
      final jitterMillis = <int>[-18, 9, 22, -7, 14, -11][index % 6];
      elapsedMicros += (150 + jitterMillis) * 1000;
      final seconds = elapsedMicros / 1000000;
      final value = math.sin(2 * math.pi * 1.2 * seconds) +
          0.04 * math.sin(2 * math.pi * 0.35 * seconds);
      latest = estimator.addSample(
            start.add(Duration(microseconds: elapsedMicros)),
            value,
          ) ??
          latest;
    }

    expect(latest, isNotNull);
    expect(latest!.bpm, isNotNull);
    expect(latest.bpm!, closeTo(72, 2));
    expect(latest.confidence, greaterThanOrEqualTo(0.5));
    expect(latest.reliable, isTrue);
  });

  test('does not fabricate BPM before the analysis window is full', () {
    final estimator = TimingAwareBpmEstimator();
    final start = DateTime(2026, 1, 1);
    BpmEstimate? latest;

    for (var index = 0; index < 60; index++) {
      latest = estimator.addSample(
            start.add(Duration(milliseconds: index * 150)),
            math.sin(index / 4),
          ) ??
          latest;
    }

    expect(latest, isNotNull);
    expect(latest!.bpm, isNull);
    expect(latest.reliable, isFalse);
  });
}
