import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityService
// ─────────────────────────────────────────────────────────────────────────────

/// Application-level wrapper for connectivity and internet reachability.
///
/// Provides:
/// - An async check for actual internet connectivity via [InternetConnection].
/// - A broadcast [Stream] that emits whenever actual internet reachability changes.
///
/// This avoids false positives where the device is connected to a Wi-Fi network
/// that has no internet access.
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    InternetConnection? internetConnection,
  })  : _connectivity = connectivity ?? Connectivity(),
        _internetConnection = internetConnection ?? InternetConnection();

  final Connectivity _connectivity;
  final InternetConnection _internetConnection;

  // ── State ──────────────────────────────────────────────────────────────────

  /// Returns `true` ONLY when the device has actual internet access.
  Future<bool> isConnected() async {
    try {
      return await _internetConnection.hasInternetAccess;
    } catch (_) {
      return false;
    }
  }

  /// Stream that emits `true`/`false` whenever internet reachability changes.
  Stream<bool> get onConnectivityChanged {
    return _internetConnection.onStatusChange.map(
      (InternetStatus status) => status == InternetStatus.connected,
    );
  }

  // ── Original Interface Helpers (Optional) ──────────────────────────────────
  
  /// Checks if ANY network interface is connected (may not have internet).
  Future<bool> hasNetworkInterface() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet);
    } catch (_) {
      return false;
    }
  }
}

