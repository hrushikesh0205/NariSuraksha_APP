import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityService
// ─────────────────────────────────────────────────────────────────────────────

/// Application-level wrapper around [connectivity_plus].
///
/// Provides:
/// - An async check for the current connectivity state.
/// - A broadcast [Stream] that emits whenever connectivity changes.
///
/// Note: `connectivity_plus` reports *interface* availability, not actual
/// internet reachability. For production apps, consider a ping-based check.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  // ── State ──────────────────────────────────────────────────────────────────

  /// Returns `true` when the device has at least one active network interface.
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnectivity(results);
    } catch (_) {
      return false;
    }
  }

  /// Stream that emits `true`/`false` whenever connectivity status changes.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((results) => _hasConnectivity(results));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _hasConnectivity(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }
}
