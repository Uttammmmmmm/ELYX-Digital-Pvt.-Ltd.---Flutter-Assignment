/// Connectivity checks.
library;

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has a usable network interface.
abstract interface class NetworkInfo {
  /// True when at least one non-`none` connectivity result is present.
  Future<bool> get isConnected;

  /// Emits on every connectivity transition; useful for auto-retry.
  Stream<bool> get onConnectivityChanged;
}

/// [NetworkInfo] backed by `connectivity_plus`.
///
/// IMPORTANT -- what this does and does not tell you:
/// This reports *interface availability*, not reachability. A device on
/// captive-portal WiFi, or one whose router has no upstream, reports connected
/// and every request still fails. So this is only ever a cheap pre-check used
/// to pick cache-first vs network-first; **a failed request remains the source
/// of truth** for "we are offline", and the repository must still handle
/// [NetworkException] after this returns true.
///
/// API note: connectivity_plus returns `List<ConnectivityResult>` (verified on
/// 7.3.1, unchanged since 6.x) because a device can be on WiFi and cellular at
/// once. Treat as offline only when the list is empty or holds nothing but
/// [ConnectivityResult.none] -- checking `== ConnectivityResult.none` against a
/// single element is the classic bug here.
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}
