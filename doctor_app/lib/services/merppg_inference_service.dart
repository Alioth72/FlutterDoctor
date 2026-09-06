import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'bpm_frame_capture_service.dart';

typedef MerppgResultCallback = void Function(MerppgResult result);
typedef MerppgDiagnosticsCallback =
    void Function(MerppgDiagnostics diagnostics);

class MerppgResult {
  const MerppgResult({
    required this.timestamp,
    required this.bvp,
    required this.inferenceTime,
  });

  final DateTime timestamp;
  final double bvp;
  final Duration inferenceTime;
}

class MerppgDiagnostics {
  const MerppgDiagnostics({
    required this.status,
    required this.ready,
    required this.processedSamples,
    required this.droppedFrames,
    required this.lastInferenceTime,
    this.latestBvp,
    this.error,
  });

  const MerppgDiagnostics.loading()
    : status = 'Loading ME-rPPG model…',
      ready = false,
      processedSamples = 0,
      droppedFrames = 0,
      lastInferenceTime = Duration.zero,
      latestBvp = null,
      error = null;

  final String status;
  final bool ready;
  final int processedSamples;
  final int droppedFrames;
  final Duration lastInferenceTime;
  final double? latestBvp;
  final String? error;
}

/// Runs the official ME-rPPG model one face frame at a time.
///
/// The model is recurrent: outputs 1–36 replace inputs 1–36 after every
/// successful inference. Input 37 is the actual elapsed time between accepted
/// frames, matching the official browser implementation.
class MerppgInferenceService {
  MerppgInferenceService({
    required this.onResult,
    required this.onDiagnostics,
  });

  static const String _modelAsset =
      'assets/models/me_rppg_model.onnx';
  static const String _stateAsset = 'assets/models/me_rppg_state.bin';
  static const String _manifestAsset =
      'assets/models/me_rppg_state_manifest.json';
  static const int _stateCount = 36;

  final MerppgResultCallback onResult;
  final MerppgDiagnosticsCallback onDiagnostics;

  final Map<String, OrtValue> _state = <String, OrtValue>{};
  Future<void>? _initialization;
  Completer<void>? _processingCompleter;
  OrtSession? _session;
  bool _ready = false;
  bool _processing = false;
  bool _disposed = false;
  int _processedSamples = 0;
  int _droppedFrames = 0;
  DateTime? _lastAcceptedTimestamp;
  double? _latestBvp;
  Duration _lastInferenceTime = Duration.zero;
  String? _error;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _report(status: 'Loading ME-rPPG model…');
    OrtSession? session;
    final loadedState = <String, OrtValue>{};
    try {
      session = await OnnxRuntime().createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(
          intraOpNumThreads: 2,
          interOpNumThreads: 1,
          useArena: true,
        ),
      );
      _validateModelContract(session);

      final manifestText = await rootBundle.loadString(_manifestAsset);
      final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
      final binary = await rootBundle.load(_stateAsset);
      final tensors = (manifest['tensors'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (tensors.length != _stateCount ||
          manifest['format'] != 'float32-little-endian') {
        throw const FormatException('Unsupported ME-rPPG state manifest.');
      }

      for (final tensor in tensors) {
        final name = tensor['name'] as String;
        final shape = (tensor['shape'] as List<dynamic>).cast<int>();
        final offsetBytes = tensor['offsetBytes'] as int;
        final elementCount = tensor['elementCount'] as int;
        if (!session.inputNames.skip(1).take(_stateCount).contains(name)) {
          throw FormatException('Unexpected ME-rPPG state tensor: $name');
        }
        final values = Float32List.view(
          binary.buffer,
          binary.offsetInBytes + offsetBytes,
          elementCount,
        );
        loadedState[name] = await OrtValue.fromList(values, shape);
      }

      if (_disposed) {
        await _disposeValues(loadedState.values);
        await session.close();
        return;
      }
      _session = session;
      _state.addAll(loadedState);
      _ready = true;
      _error = null;
      _report(status: 'Raw BVP active');
    } catch (error, stackTrace) {
      await _disposeValues(loadedState.values);
      await session?.close();
      _error = error.toString();
      debugPrint('ME-rPPG initialization failed: $error\n$stackTrace');
      _report(status: 'ME-rPPG unavailable');
    }
  }

  void _validateModelContract(OrtSession session) {
    if (session.inputNames.length != 38 ||
        session.outputNames.length != 37 ||
        session.inputNames.first != 'arg_0.1' ||
        session.inputNames.last != 'onnx::Mul_37') {
      throw const FormatException(
        'The bundled ONNX file does not match the official ME-rPPG contract.',
      );
    }
  }

  Future<void> process(CapturedFaceFrame frame) async {
    if (_disposed) return;
    if (!_ready || _processing) {
      _droppedFrames++;
      _report(status: _ready ? 'Raw BVP active' : 'Loading ME-rPPG model…');
      return;
    }

    _processing = true;
    _processingCompleter = Completer<void>();
    final stopwatch = Stopwatch()..start();
    OrtValue? frameValue;
    OrtValue? elapsedValue;
    Map<String, OrtValue> outputs = <String, OrtValue>{};
    var adoptedOutputs = false;
    try {
      final previousTimestamp = _lastAcceptedTimestamp;
      final elapsedSeconds = previousTimestamp == null
          ? 1 / 30
          : frame.timestamp.difference(previousTimestamp).inMicroseconds /
                Duration.microsecondsPerSecond;
      final boundedElapsed = elapsedSeconds.clamp(1 / 90, 0.5).toDouble();

      frameValue = await OrtValue.fromList(
        frame.rgb,
        const <int>[1, 1, 36, 36, 3],
      );
      elapsedValue = await OrtValue.fromList(
        Float32List.fromList(<double>[boundedElapsed]),
        const <int>[],
      );

      final session = _session!;
      final inputs = <String, OrtValue>{
        session.inputNames.first: frameValue,
        ..._state,
        session.inputNames.last: elapsedValue,
      };
      outputs = await session.run(inputs);

      final bvpTensor = outputs[session.outputNames.first];
      if (bvpTensor == null) {
        throw StateError('ME-rPPG did not return a BVP output.');
      }
      final bvpValues = await bvpTensor.asFlattenedList();
      if (bvpValues.isEmpty || bvpValues.first is! num) {
        throw const FormatException('ME-rPPG returned an invalid BVP value.');
      }

      final nextState = <String, OrtValue>{};
      for (var index = 1; index <= _stateCount; index++) {
        final output = outputs[session.outputNames[index]];
        if (output == null) {
          throw StateError('ME-rPPG state output $index is missing.');
        }
        nextState[session.inputNames[index]] = output;
      }

      final previousState = _state.values.toList(growable: false);
      _state
        ..clear()
        ..addAll(nextState);
      adoptedOutputs = true;
      await _disposeValues(previousState);
      await bvpTensor.dispose();

      stopwatch.stop();
      _lastInferenceTime = stopwatch.elapsed;
      _lastAcceptedTimestamp = frame.timestamp;
      _latestBvp = (bvpValues.first as num).toDouble();
      _processedSamples++;
      _error = null;
      onResult(
        MerppgResult(
          timestamp: frame.timestamp,
          bvp: _latestBvp!,
          inferenceTime: _lastInferenceTime,
        ),
      );
      _report(status: 'Raw BVP active');
    } catch (error, stackTrace) {
      _error = error.toString();
      debugPrint('ME-rPPG inference failed: $error\n$stackTrace');
      _report(status: 'ME-rPPG error');
    } finally {
      if (!adoptedOutputs) await _disposeValues(outputs.values);
      await frameValue?.dispose();
      await elapsedValue?.dispose();
      _processing = false;
      _processingCompleter?.complete();
      _processingCompleter = null;
    }
  }

  void _report({required String status}) {
    if (_disposed) return;
    onDiagnostics(
      MerppgDiagnostics(
        status: status,
        ready: _ready,
        processedSamples: _processedSamples,
        droppedFrames: _droppedFrames,
        lastInferenceTime: _lastInferenceTime,
        latestBvp: _latestBvp,
        error: _error,
      ),
    );
  }

  Future<void> _disposeValues(Iterable<OrtValue> values) async {
    await Future.wait(values.map((value) => value.dispose()));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _initialization;
    } catch (_) {
      // Initialization already reported its own error.
    }
    await _processingCompleter?.future;
    await _disposeValues(_state.values);
    _state.clear();
    await _session?.close();
    _session = null;
    _ready = false;
  }
}
