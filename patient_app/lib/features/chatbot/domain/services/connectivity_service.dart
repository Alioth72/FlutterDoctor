/// Domain contract for network connectivity monitoring.
abstract class ConnectivityService {
  /// Returns true if the device currently has active internet reachability.
  Future<bool> get isOnline;

  /// Reactive stream emitting connectivity state changes (true = online, false = offline).
  Stream<bool> get onConnectivityChanged;

  /// Disposes controllers or active network listeners.
  void close();
}
