import 'dart:math' as math;

import 'vitals_models.dart';

class _TimedBvp {
  const _TimedBvp(this.timestamp, this.value);

  final DateTime timestamp;
  final double value;
}

/// Converts an irregular ME-rPPG BVP stream into confidence-gated BPM.
///
/// Samples are linearly resampled from their real capture timestamps before a
/// 0.7 Hz high-pass and a sample-rate-safe low-pass are applied. A Hann-windowed
/// Welch-style spectrum finds the pulse peak; normalized autocorrelation and
/// spectral concentration form the signal-quality score.
class TimingAwareBpmEstimator {
  static const Duration _analysisWindow = Duration(seconds: 20);
  static const Duration _analysisInterval = Duration(seconds: 2);
  static const double _minimumFrequencyHz = 0.7;
  static const double _requestedMaximumFrequencyHz = 4.0;

  final List<_TimedBvp> _samples = <_TimedBvp>[];
  DateTime? _lastAnalysisAt;

  BpmEstimate? addSample(DateTime timestamp, double value) {
    if (!value.isFinite) return null;
    if (_samples.isNotEmpty && !timestamp.isAfter(_samples.last.timestamp)) {
      return null;
    }
    _samples.add(_TimedBvp(timestamp, value));
    final cutoff = timestamp.subtract(_analysisWindow);
    _samples.removeWhere((sample) => sample.timestamp.isBefore(cutoff));

    if (_lastAnalysisAt != null &&
        timestamp.difference(_lastAnalysisAt!) < _analysisInterval) {
      return null;
    }
    _lastAnalysisAt = timestamp;
    return _analyse(timestamp);
  }

  BpmEstimate _analyse(DateTime timestamp) {
    if (_samples.length < 40) {
      return _waiting(timestamp, 'Collecting pulse signal…');
    }
    final elapsedSeconds =
        _samples.last.timestamp
            .difference(_samples.first.timestamp)
            .inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsedSeconds < _analysisWindow.inSeconds * 0.9) {
      return _waiting(
        timestamp,
        'Collecting ${elapsedSeconds.floor()}/${_analysisWindow.inSeconds}s…',
      );
    }

    final sampleRate = (_samples.length - 1) / elapsedSeconds;
    final maximumFrequency = math.min(
      _requestedMaximumFrequencyHz,
      sampleRate * 0.45,
    );
    if (maximumFrequency <= _minimumFrequencyHz + 0.2) {
      return BpmEstimate(
        timestamp: timestamp,
        status: 'Sampling rate too low',
        confidence: 0,
        effectiveSampleRate: sampleRate,
        sampleCount: _samples.length,
        maximumResolvableBpm: maximumFrequency * 60,
      );
    }

    final uniform = _resampleUniformly(_samples);
    final detrended = _removeLinearTrend(uniform);
    final highPassed = _biquad(
      detrended,
      sampleRate: sampleRate,
      cutoff: _minimumFrequencyHz,
      highPass: true,
    );
    final filtered = _biquad(
      highPassed,
      sampleRate: sampleRate,
      cutoff: maximumFrequency,
      highPass: false,
    );
    final spectrum = _welchSpectrum(
      filtered,
      sampleRate: sampleRate,
      minimumFrequency: _minimumFrequencyHz,
      maximumFrequency: maximumFrequency,
    );
    if (spectrum.powers.isEmpty) {
      return _waiting(timestamp, 'Measuring pulse quality…', sampleRate);
    }

    var peakIndex = 0;
    for (var index = 1; index < spectrum.powers.length; index++) {
      if (spectrum.powers[index] > spectrum.powers[peakIndex]) {
        peakIndex = index;
      }
    }
    final peakFrequency = spectrum.frequencies[peakIndex];
    final bpm = peakFrequency * 60;
    final periodicity = _periodicity(
      filtered,
      sampleRate: sampleRate,
      peakFrequency: peakFrequency,
    );
    final totalPower = spectrum.powers.fold<double>(0, (a, b) => a + b);
    var peakBandPower = 0.0;
    for (var index = 0; index < spectrum.powers.length; index++) {
      if ((spectrum.frequencies[index] - peakFrequency).abs() <= 0.15) {
        peakBandPower += spectrum.powers[index];
      }
    }
    final concentration = totalPower <= 0 ? 0.0 : peakBandPower / totalPower;
    final spectralQuality = (concentration / 0.5).clamp(0.0, 1.0);
    final confidence = (0.65 * periodicity + 0.35 * spectralQuality).clamp(
      0.0,
      1.0,
    );

    return BpmEstimate(
      timestamp: timestamp,
      status: confidence >= 0.5 ? 'Reliable estimate' : 'Low signal quality',
      confidence: confidence,
      effectiveSampleRate: sampleRate,
      sampleCount: _samples.length,
      maximumResolvableBpm: maximumFrequency * 60,
      bpm: bpm,
    );
  }

  BpmEstimate _waiting(
    DateTime timestamp,
    String status, [
    double sampleRate = 0,
  ]) => BpmEstimate(
    timestamp: timestamp,
    status: status,
    confidence: 0,
    effectiveSampleRate: sampleRate,
    sampleCount: _samples.length,
    maximumResolvableBpm: sampleRate * 0.45 * 60,
  );

  List<double> _resampleUniformly(List<_TimedBvp> samples) {
    final firstMicros = samples.first.timestamp.microsecondsSinceEpoch;
    final spanMicros =
        samples.last.timestamp.microsecondsSinceEpoch - firstMicros;
    final result = List<double>.filled(samples.length, 0);
    var sourceIndex = 0;
    for (var index = 0; index < result.length; index++) {
      final target = firstMicros + spanMicros * index / (result.length - 1);
      while (sourceIndex + 1 < samples.length - 1 &&
          samples[sourceIndex + 1].timestamp.microsecondsSinceEpoch < target) {
        sourceIndex++;
      }
      final left = samples[sourceIndex];
      final right = samples[sourceIndex + 1];
      final leftMicros = left.timestamp.microsecondsSinceEpoch;
      final rightMicros = right.timestamp.microsecondsSinceEpoch;
      final fraction = rightMicros == leftMicros
          ? 0.0
          : (target - leftMicros) / (rightMicros - leftMicros);
      result[index] = left.value + (right.value - left.value) * fraction;
    }
    return result;
  }

  List<double> _removeLinearTrend(List<double> values) {
    final n = values.length;
    final meanX = (n - 1) / 2;
    final meanY = values.fold<double>(0, (a, b) => a + b) / n;
    var covariance = 0.0;
    var variance = 0.0;
    for (var index = 0; index < n; index++) {
      final dx = index - meanX;
      covariance += dx * (values[index] - meanY);
      variance += dx * dx;
    }
    final slope = variance == 0 ? 0.0 : covariance / variance;
    return List<double>.generate(
      n,
      (index) => values[index] - (meanY + slope * (index - meanX)),
      growable: false,
    );
  }

  List<double> _biquad(
    List<double> input, {
    required double sampleRate,
    required double cutoff,
    required bool highPass,
  }) {
    final omega = 2 * math.pi * cutoff / sampleRate;
    final cosine = math.cos(omega);
    final sine = math.sin(omega);
    final alpha = sine / (2 * math.sqrt1_2);
    final a0 = 1 + alpha;
    final b0 = (highPass ? 1 + cosine : 1 - cosine) / 2 / a0;
    final b1 = (highPass ? -(1 + cosine) : 1 - cosine) / a0;
    final b2 = b0;
    final a1 = -2 * cosine / a0;
    final a2 = (1 - alpha) / a0;
    final output = List<double>.filled(input.length, 0);
    var x1 = 0.0;
    var x2 = 0.0;
    var y1 = 0.0;
    var y2 = 0.0;
    for (var index = 0; index < input.length; index++) {
      final x0 = input[index];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      output[index] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
    return output;
  }

  _Spectrum _welchSpectrum(
    List<double> signal, {
    required double sampleRate,
    required double minimumFrequency,
    required double maximumFrequency,
  }) {
    final desiredLength = (sampleRate * 10).round().clamp(32, 128);
    final segmentLength = math.min(signal.length, desiredLength);
    if (segmentLength < 24) return const _Spectrum(<double>[], <double>[]);
    final step = math.max(1, segmentLength ~/ 2);
    final frequencies = <double>[];
    for (
      var frequency = minimumFrequency;
      frequency <= maximumFrequency;
      frequency += 0.01
    ) {
      frequencies.add(frequency);
    }
    final powers = List<double>.filled(frequencies.length, 0);
    var segmentCount = 0;
    for (var start = 0; start + segmentLength <= signal.length; start += step) {
      final mean =
          signal
              .skip(start)
              .take(segmentLength)
              .fold<double>(0, (a, b) => a + b) /
          segmentLength;
      for (
        var frequencyIndex = 0;
        frequencyIndex < frequencies.length;
        frequencyIndex++
      ) {
        var real = 0.0;
        var imaginary = 0.0;
        final frequency = frequencies[frequencyIndex];
        for (var index = 0; index < segmentLength; index++) {
          final window =
              0.5 - 0.5 * math.cos(2 * math.pi * index / (segmentLength - 1));
          final value = (signal[start + index] - mean) * window;
          final angle = 2 * math.pi * frequency * index / sampleRate;
          real += value * math.cos(angle);
          imaginary -= value * math.sin(angle);
        }
        powers[frequencyIndex] += real * real + imaginary * imaginary;
      }
      segmentCount++;
    }
    if (segmentCount > 0) {
      for (var index = 0; index < powers.length; index++) {
        powers[index] /= segmentCount;
      }
    }
    return _Spectrum(frequencies, powers);
  }

  double _periodicity(
    List<double> signal, {
    required double sampleRate,
    required double peakFrequency,
  }) {
    final centreLag = sampleRate / peakFrequency;
    final minimumLag = math.max(1, (centreLag * 0.85).floor());
    final maximumLag = math.min(signal.length - 2, (centreLag * 1.15).ceil());
    var best = 0.0;
    for (var lag = minimumLag; lag <= maximumLag; lag++) {
      var numerator = 0.0;
      var energyA = 0.0;
      var energyB = 0.0;
      for (var index = 0; index + lag < signal.length; index++) {
        final a = signal[index];
        final b = signal[index + lag];
        numerator += a * b;
        energyA += a * a;
        energyB += b * b;
      }
      final denominator = math.sqrt(energyA * energyB);
      if (denominator > 0) best = math.max(best, numerator / denominator);
    }
    return best.clamp(0.0, 1.0);
  }
}

class _Spectrum {
  const _Spectrum(this.frequencies, this.powers);

  final List<double> frequencies;
  final List<double> powers;
}
