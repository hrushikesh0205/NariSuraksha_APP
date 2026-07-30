import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/core/services/connectivity_service.dart';
import 'package:nari_suraksha/core/services/location_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';
import 'package:geolocator/geolocator.dart';
// ─────────────────────────────────────────────────────────────────────────────
// SafetyStatus
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// DashboardProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Central state container for the Home Dashboard screen.
///
/// Manages:
/// - [SafetyStatus] — real GPS, permission, and internet state.
/// - Recent activity logs stream subscription.
/// - SOS trigger flow (location → Firestore write → activity log).
/// - Loading / error states for each section independently.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    LocationService? locationService,
    ConnectivityService? connectivityService,
    AuthService? authService,
    SosRepository? sosRepository,
    ActivityRepository? activityRepository,
    UserProvider? userProvider,
  })  : _locationService = locationService ?? LocationService(),
        _connectivityService = connectivityService ?? ConnectivityService(),
        _authService = authService ?? AuthService(),
        _sosRepository = sosRepository ?? SosRepository(),
        _activityRepository = activityRepository ?? ActivityRepository(),
        _userProvider = userProvider;

  final LocationService _locationService;
  final ConnectivityService _connectivityService;
  final AuthService _authService;
  final SosRepository _sosRepository;
  final ActivityRepository _activityRepository;
  final UserProvider? _userProvider;

  // ── State ──────────────────────────────────────────────────────────────────

  SafetyStatus _safetyStatus = SafetyStatus.unknown;
  List<ActivityLogModel> _recentAlerts = [];
  bool _isInitializing = true;
  bool _isSosTriggerLoading = false;
  String? _sosErrorMessage;
  String? _alertsErrorMessage;

  SafetyStatus get safetyStatus => _safetyStatus;
  List<ActivityLogModel> get recentAlerts => _recentAlerts;
  bool get isInitializing => _isInitializing;
  bool get isSosTriggerLoading => _isSosTriggerLoading;
  String? get sosErrorMessage => _sosErrorMessage;
  String? get alertsErrorMessage => _alertsErrorMessage;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Called once when the Dashboard mounts.
  ///
  /// Loads all dashboard sections in parallel. Safe to call again to refresh.
  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    await Future.wait([
      _refreshSafetyStatus(),
      _loadRecentAlerts(),
      if (_userProvider != null) _userProvider.loadUser(),
    ]);

    _isInitializing = false;
    notifyListeners();
  }

  // ── Safety Status ──────────────────────────────────────────────────────────

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

  // ── SOS Trigger ────────────────────────────────────────────────────────────

  /// Full SOS flow: get location → write Firestore → log activity.
  ///
  /// Returns a [SosTriggerResult] describing success or the error.
  Future<SosTriggerResult> triggerSos() async {
    final uid = _authService.firebaseUser?.uid;
    if (uid == null) {
      return SosTriggerResult.failure('Not signed in. Please log in first.');
    }

    _isSosTriggerLoading = true;
    _sosErrorMessage = null;
    notifyListeners();

    try {
      // 1. Get location (allow fallback to last-known if fresh fix times out)
      Position? position;
      try {
        position = await _locationService.getCurrentPosition();
      } catch (_) {
        position = await _locationService.getLastKnownPosition();
      }

      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      // 2. Write SOS record to Firestore
      final record = SosRecordModel(
        userId: uid,
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        status: SosStatus.active,
      );
      await _sosRepository.createSosRecord(record);

      // 3. Log activity for Recent Alerts feed
      await _activityRepository.logActivity(
        uid: uid,
        type: ActivityLogType.sosActivated,
        description: position != null
            ? 'SOS triggered at (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'
            : 'SOS triggered — location unavailable',
      );

      // 4. Refresh alerts list
      await _loadRecentAlerts();

      return SosTriggerResult.success(lat, lng);
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

  // ── Recent Alerts ──────────────────────────────────────────────────────────

  Future<void> _loadRecentAlerts() async {
    final uid = _authService.firebaseUser?.uid;
    if (uid == null) {
      _recentAlerts = [];
      notifyListeners();
      return;
    }

    try {
      _recentAlerts = await _activityRepository.getRecentActivity(
        uid,
        limit: 10,
      );
      _alertsErrorMessage = null;
    } catch (e) {
      _alertsErrorMessage = _friendlyError(e);
      _recentAlerts = [];
    }
    notifyListeners();
  }

  Future<void> refreshAlerts() => _loadRecentAlerts();

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('location service')) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SosTriggerResult
// ─────────────────────────────────────────────────────────────────────────────

/// Result of a [DashboardProvider.triggerSos] call.
sealed class SosTriggerResult {
  const SosTriggerResult();

  factory SosTriggerResult.success(double lat, double lng) =>
      _SosSuccess(lat, lng);

  factory SosTriggerResult.failure(String reason) => _SosFailure(reason);
}

class _SosSuccess extends SosTriggerResult {
  const _SosSuccess(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class _SosFailure extends SosTriggerResult {
  const _SosFailure(this.reason);
  final String reason;
}

extension SosTriggerResultX on SosTriggerResult {
  bool get isSuccess => this is _SosSuccess;
  String? get failureReason =>
      this is _SosFailure ? (this as _SosFailure).reason : null;
}
