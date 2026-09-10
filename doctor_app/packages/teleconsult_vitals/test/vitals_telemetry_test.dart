import 'package:teleconsult_vitals/teleconsult_vitals.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips a vitals sample with an estimate', () {
    final timestamp = DateTime.fromMicrosecondsSinceEpoch(1234567890);
    final message = VitalsSampleTelemetry(
      timestamp: timestamp,
      bvp: 0.42,
      inferenceTime: const Duration(milliseconds: 18),
      processedSamples: 120,
      droppedFrames: 3,
      estimate: BpmEstimate(
        timestamp: timestamp,
        status: 'Reliable estimate',
        confidence: 0.82,
        effectiveSampleRate: 14.8,
        sampleCount: 120,
        maximumResolvableBpm: 240,
        bpm: 72.5,
      ),
    );

    final decoded = VitalsTelemetryMessage.tryParse(message.toJson());

    expect(decoded, isA<VitalsSampleTelemetry>());
    final sample = decoded! as VitalsSampleTelemetry;
    expect(sample.timestamp, timestamp);
    expect(sample.bvp, closeTo(0.42, 0.0001));
    expect(sample.estimate?.bpm, closeTo(72.5, 0.0001));
    expect(sample.estimate?.reliable, isTrue);
  });

  test('rejects unknown versions and malformed timestamps', () {
    expect(
      VitalsTelemetryMessage.tryParse(<String, dynamic>{
        'type': 'vitalsSample',
        'version': 2,
      }),
      isNull,
    );
    expect(
      VitalsTelemetryMessage.tryParse(<String, dynamic>{
        'type': 'vitalsSample',
        'version': vitalsTelemetryVersion,
        'timestampMicros': 'invalid',
      }),
      isNull,
    );
  });
}
