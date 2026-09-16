import 'dart:async';
import 'dart:io';

import '../../domain/services/connectivity_service.dart';

/// Concrete [ConnectivityService] using standard DNS address lookups.
class DefaultConnectivityService implements ConnectivityService {
  DefaultConnectivityService({
    this.lookupHost = 'google.com',
    this.timeout = const Duration(seconds: 5),
  });

  final String lookupHost;
  final Duration timeout;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async {
    try {
      final result = await InternetAddress.lookup(lookupHost).timeout(timeout);
      final online = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      _controller.add(online);
      return online;
    } catch (_) {
      _controller.add(false);
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  void close() {
    _controller.close();
  }
}

/// Controllable [ConnectivityService] specifically designed for unit testing.
class MockConnectivityService implements ConnectivityService {
  MockConnectivityService({bool initialOnline = true}) : _isOnline = initialOnline;

  bool _isOnline;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  /// Programmatically toggles network state and notifies subscribers.
  void setOnline(bool online) {
    _isOnline = online;
    _controller.add(online);
  }

  @override
  Future<bool> get isOnline async => _isOnline;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  void close() {
    _controller.close();
  }
}
