import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/connectivity_service.dart';
import 'package:nari_suraksha/services/sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConnectivityProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Global connectivity state for the app.
///
/// Exposes [isOnline] for UI banners and conditional logic.
/// Triggers [SyncService.syncAll] when connectivity is restored (OFFLINE→ONLINE).
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider({
    ConnectivityService? connectivityService,
    SyncService? syncService,
  })  : _connectivityService = connectivityService ?? ConnectivityService(),
        _syncService = syncService ?? SyncService() {
    _init();
  }

  final ConnectivityService _connectivityService;
  final SyncService _syncService;

  bool _isOnline = true;
  StreamSubscription<bool>? _sub;

  // ── Public getters ─────────────────────────────────────────────────────────

  /// True when the device has verified internet access.
  bool get isOnline => _isOnline;

  /// True when the device is offline.
  bool get isOffline => !_isOnline;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Set initial state
    try {
      _isOnline = await _connectivityService.isConnected();
    } catch (_) {
      _isOnline = true; // Optimistic default
    }
    notifyListeners();

    // Listen for changes
    _sub = _connectivityService.onConnectivityChanged.listen((isConnected) {
      final wasOffline = !_isOnline;
      _isOnline = isConnected;
      notifyListeners();

      debugPrint(
          '📡 ConnectivityProvider: connectivity changed → isOnline=$_isOnline');

      // Trigger sync when transitioning from OFFLINE → ONLINE
      if (wasOffline && isConnected) {
        debugPrint('🔄 ConnectivityProvider: Going online — triggering sync');
        _syncService.syncAll();
      }
    });
  }

  /// Manually refreshes the connectivity state (e.g. after user taps retry).
  Future<void> refresh() async {
    try {
      _isOnline = await _connectivityService.isConnected();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
