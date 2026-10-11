import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/core/services/connectivity_service.dart';
import 'package:nari_suraksha/core/services/location_service.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/local_sos_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';
import 'package:geolocator/geolocator.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SafetyStatus
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Snapshot of device safety / connectivity status shown in the status card.
class SafetyStatus {
  const SafetyStatus({
    required this.isLocationEnabled,
    required this.hasLocationPermission,
    required this.isConnected,
    this.lastUpdated,
  });

  final bool isLocationEnabled;
  final bool hasLocationPermission;
  final bool isConnected;
  final DateTime? lastUpdated;

  bool get isSafe =>
      isLocationEnabled && hasLocationPermission && isConnected;

  static const SafetyStatus unknown = SafetyStatus(
    isLocationEnabled: false,
    hasLocationPermission: false,
    isConnected: false,
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// DashboardProvider
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Central state container for the Home Dashboard screen.
///
/// Manages:
/// - [SafetyStatus] â€” real GPS, permission, and internet state.
///   Auto-updates via a [ConnectivityService.onConnectivityChanged] stream
///   so the status card reacts within seconds of WiFi being toggled.
/// - Recent activity logs via real-time Firestore stream.
/// - SOS trigger flow (location â†’ Firestore write â†’ activity log).
/// - Loading / error states for each section independently.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    LocationService? locationService,
    ConnectivityService? connectivityService,
    AuthService? authService,
    SosRepository? sosRepository,
    ActivityRepository? activityRepository,
    SmsService? smsService,
    UserProvider? userProvider,
    LocalSosRepository? localSosRepository,
  })  : _locationService = locationService ?? LocationService(),
        _connectivityService = connectivityService ?? ConnectivityService(),
        _authService = authService ?? AuthService(),
        _sosRepository = sosRepository ?? SosRepository(),
        _activityRepository = activityRepository ?? ActivityRepository(),
        _smsService = smsService ?? const SmsService(),
        _localSosRepository = localSosRepository ?? LocalSosRepository(),
        _userProvider = userProvider;

  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final AuthService _authService;
  final SosRepository _sosRepository;
  final ActivityRepository _activityRepository;
  final SmsService _smsService;
  final LocalSosRepository _localSosRepository;
  final UserProvider? _userProvider;

  // â”€â”€ State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  SafetyStatus _safetyStatus = SafetyStatus.unknown;
  List<ActivityLogModel> _recentAlerts = [];
  bool _isInitializing = true;
  bool _isSosTriggerLoading = false;
  String? _sosErrorMessage;
  String? _alertsErrorMessage;

  /// Real-time subscription for recent activity logs.
  StreamSubscription<List<ActivityLogModel>>? _alertsSub;

  /// Live connectivity subscription â€” auto-refreshes safety status on change.
  StreamSubscription<bool>? _connectivitySub;

  SafetyStatus get safetyStatus => _safetyStatus;
  List<ActivityLogModel> get recentAlerts => _recentAlerts;
  bool get isInitializing => _isInitializing;
  bool get isSosTriggerLoading => _isSosTriggerLoading;
  String? get sosErrorMessage => _sosErrorMessage;
  String? get alertsErrorMessage => _alertsErrorMessage;

  // â”€â”€ Computed stats â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Number of SOS events in the current recent-alert window.
  int get sosCount =>
      _recentAlerts.where((a) => a.type == ActivityLogType.sosActivated).length;

  /// Human-readable location status label for the stats row.
  String get locationStatusLabel {
    if (!_safetyStatus.isLocationEnabled) return 'Location Disabled';
    if (!_safetyStatus.hasLocationPermission) return 'Permission Required';
    return 'Location Ready';
  }

  /// Whether the device currently has internet connectivity.
  bool get isConnected => _safetyStatus.isConnected;

  // â”€â”€ Initialization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Called once when the Dashboard mounts.
  ///
  /// Loads all dashboard sections in parallel. Safe to call again to refresh.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    await Future.wait([
      _refreshSafetyStatus(),
      if (_userProvider != null) _userProvider.loadUser(),
    ]);

    // Start real-time stream for recent alerts.
    _subscribeToAlerts();

    // Subscribe to connectivity changes so the status card auto-updates
    // when the user toggles WiFi / mobile data mid-session.
    _subscribeToConnectivity();

    _isInitializing = false;
    notifyListeners();
  }

  // â”€â”€ Safety Status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _refreshSafetyStatus() async {
    try {
      final connected = await _connectivityService.isConnected();
      final permResult = await _locationService.checkPermission();
      final locationEnabled =
          await _locationService.isLocationServiceEnabled();

      _safetyStatus = SafetyStatus(
        isLocationEnabled: locationEnabled,
        hasLocationPermission: permResult is LocationPermissionGranted,
        isConnected: connected,
        lastUpdated: DateTime.now(),
      );
    } catch (_) {
      _safetyStatus = SafetyStatus.unknown;
    }
    notifyListeners();
  }

  Future<void> refreshSafetyStatus() => _refreshSafetyStatus();

  // â”€â”€ Live connectivity subscription â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Subscribes to connectivity changes. When connectivity toggles,
  /// immediately re-checks the full safety status so the card stays accurate.
  void _subscribeToConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub =
        _connectivityService.onConnectivityChanged.listen((_) async {
      // Re-evaluate the full status (not just connectivity) so all
      // three indicators update atomically.
      await _refreshSafetyStatus();
    });
  }

  // â”€â”€ SOS Trigger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Full SOS flow: get location â†’ write Firestore (or local DB if offline) â†’ log activity.
  ///
  /// **Offline Behavior**: If no internet, saves to local SQLite DB as PENDING_SYNC.
  /// The [SyncService] will upload to Firestore when connectivity returns.
  ///
  /// Accepts an optional [triggerSource] (e.g. `'Voice SOS'`) for the activity log.
  /// Returns a [SosTriggerResult] describing success or the error.
  Future<SosTriggerResult> triggerSos({String triggerSource = 'SOS'}) async {
    final uid = _authService.firebaseUser?.uid;
    if (uid == null) {
      return SosTriggerResult.failure('Not signed in. Please log in first.');
    }

    _isSosTriggerLoading = true;
    _sosErrorMessage = null;
    notifyListeners();

    try {
      // â”€â”€ Check connectivity â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
      final isOnline = await _connectivityService.isConnected();

      if (isOnline) {
        // â”€â”€ ONLINE PATH â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

        // 1. One Active Session Rule
        try {
          final recents = await _sosRepository.getRecentSos(uid, limit: 1);
          if (recents.isNotEmpty) {
            final active = recents.first;
            if (active.status == SosStatus.active && active.resolvedAt == null) {
              debugPrint(
                'â„¹ï¸ DashboardProvider: Active SOS (${active.id}) already in progress. Reusing.',
              );
              return SosTriggerResult.success(
                active.latitude,
                active.longitude,
                docId: active.id,
              );
            }
          }
        } catch (e) {
          debugPrint('âš ï¸ DashboardProvider: check existing active SOS failed: $e');
        }

        // 2. Proactively check/request SMS permission
        try {
          final perm = await _smsService.checkSmsPermission();
          if (!perm['granted']!) await _smsService.requestSmsPermission();
        } catch (_) {}

        // 3. Get location (allow fallback to last-known if fresh fix times out)
        Position? position;
        try {
          position = await _locationService.getCurrentPosition();
        } catch (e) {
          debugPrint('âš ï¸ DashboardProvider: fresh location failed, trying last-known: $e');
          position = await _locationService.getLastKnownPosition();
        }
        final lat = position?.latitude ?? 0.0;
        final lng = position?.longitude ?? 0.0;

        // 4. Write SOS record to Firestore
        final record = SosRecordModel(
          userId: uid,
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          status: SosStatus.active,
          escalationLevel: 'high',
          highAlertedAt: DateTime.now(),
        );
        final docId = await _sosRepository.createSosRecord(record);

        // 5. Also save to local DB as backup (synced status)
        final localId = _generateUuid();
        unawaited(_localSosRepository.insertHistoryRecord(
          localId: localId,
          userId: uid,
          latitude: lat,
          longitude: lng,
          startedAt: record.timestamp,
          triggerSource: triggerSource,
        ));
        unawaited(_localSosRepository.markHistorySynced(localId, docId));

        // 6. Log activity for Recent Alerts feed
        await _activityRepository.logActivity(
          uid: uid,
          type: ActivityLogType.sosActivated,
          description: position != null
              ? '$triggerSource triggered at (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'
              : '$triggerSource triggered â€” location unavailable',
        );

        unawaited(_refreshSafetyStatus());
        return SosTriggerResult.success(lat, lng, docId: docId);
      } else {
        // â”€â”€ OFFLINE PATH â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        debugPrint('ðŸ“´ DashboardProvider: OFFLINE â€” saving SOS to local DB');

        // 1. Proactively check/request SMS permission (works offline)
        try {
          final perm = await _smsService.checkSmsPermission();
          if (!perm['granted']!) await _smsService.requestSmsPermission();
        } catch (_) {}

        // 2. Get GPS location (works offline â€” no internet needed)
        Position? position;
        try {
          position = await _locationService.getCurrentPosition();
        } catch (e) {
          debugPrint('âš ï¸ DashboardProvider [offline]: location failed: $e');
          position = await _locationService.getLastKnownPosition();
        }
        final lat = position?.latitude ?? 0.0;
        final lng = position?.longitude ?? 0.0;
        final now = DateTime.now();

        // 3. Generate stable local UUID â€” becomes the Firestore doc ID on sync
        final localId = _generateUuid();

        // 4. Save SOS history record as PENDING_SYNC
        await _localSosRepository.insertHistoryRecord(
          localId: localId,
          userId: uid,
          latitude: lat,
          longitude: lng,
          startedAt: now,
          triggerSource: triggerSource,
          status: 'active',
          escalationLevel: 'high',
        );

        // 5. Save as active session so escalation can resume after app restart
        await _localSosRepository.saveActiveSession(
          sosDocId: localId,
          userId: uid,
          latitude: lat,
          longitude: lng,
          startedAt: now,
          currentLevel: 'high',
          triggerSource: triggerSource,
          syncStatus: 'pending',
        );

        debugPrint('âœ… DashboardProvider [offline]: SOS saved locally as $localId');
        unawaited(_refreshSafetyStatus());
        return SosTriggerResult.success(lat, lng, docId: localId);
      }
    } catch (e) {
      final msg = _friendlyError(e);
      _sosErrorMessage = msg;
      notifyListeners();
      return SosTriggerResult.failure(msg);
    } finally {
      _isSosTriggerLoading = false;
      notifyListeners();
    }
  }

  /// Generates a UUID v4 for offline SOS record identification.
  String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // â”€â”€ Recent Alerts â€” real-time stream â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _subscribeToAlerts([String? explicitUid]) {
    final uid = explicitUid ??
        _userProvider?.currentUid ??
        _authService.firebaseUser?.uid;
    if (uid == null || uid.isEmpty) {
      _recentAlerts = [];
      _alertsErrorMessage = null;
      notifyListeners();
      return;
    }

    // Cancel any existing subscription before creating a new one.
    _alertsSub?.cancel();
    _alertsSub = _activityRepository
        .watchRecentActivity(uid, limit: 10)
        .listen(
      (list) {
        _recentAlerts = list;
        _alertsErrorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        _alertsErrorMessage = _friendlyError(e);
        _recentAlerts = [];
        notifyListeners();
      },
    );
  }

  /// Force-restarts the real-time alert subscription (e.g. after retry tap).
  void refreshAlerts([String? uid]) => _subscribeToAlerts(uid);

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('unavailable') || msg.contains('offline')) {
      return 'You are offline. Please check your internet connection.';
    }
    if (msg.contains('permission-denied') || msg.contains('permission_denied')) {
      return 'Firestore permission denied. Please contact support.';
    }
    if (msg.contains('location service') || msg.contains('location disabled')) {
      return 'Location services are disabled. Please enable GPS.';
    }
    if (msg.contains('permission')) {
      return 'Location permission is required for SOS.';
    }
    if (msg.contains('timeout')) {
      return 'Location timed out. SOS sent without precise location.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _alertsSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SosTriggerResult
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// Result of a [DashboardProvider.triggerSos] call.
sealed class SosTriggerResult {
  const SosTriggerResult();

  factory SosTriggerResult.success(double lat, double lng, {String? docId}) =>
      _SosSuccess(lat, lng, docId: docId);

  factory SosTriggerResult.failure(String reason) => _SosFailure(reason);
}

class _SosSuccess extends SosTriggerResult {
  const _SosSuccess(this.latitude, this.longitude, {this.docId});
  final double latitude;
  final double longitude;
  final String? docId;
}

class _SosFailure extends SosTriggerResult {
  const _SosFailure(this.reason);
  final String reason;
}

extension SosTriggerResultX on SosTriggerResult {
  bool get isSuccess => this is _SosSuccess;

  String? get failureReason =>
      this is _SosFailure ? (this as _SosFailure).reason : null;

  String? get docId =>
      this is _SosSuccess ? (this as _SosSuccess).docId : null;

  /// Google Maps URL for the triggered location (null if this is a failure).
  String? get mapsUrl {
    if (this is _SosSuccess) {
      final s = this as _SosSuccess;
      return 'https://maps.google.com/?q=${s.latitude},${s.longitude}';
    }
    return null;
  }
}
