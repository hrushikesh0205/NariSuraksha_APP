import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActiveSosSession
// ─────────────────────────────────────────────────────────────────────────────

/// Represents an ongoing Emergency SOS escalation session.
class ActiveSosSession {
  ActiveSosSession({
    required this.sosDocId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    required this.startedAt,
    this.currentLevel = ContactPriority.high,
    this.isResolved = false,
    this.resolvedAt,
    Set<ContactPriority>? alertedPriorities,
    Set<String>? alertedContactPhones,
  })  : alertedPriorities = alertedPriorities ?? {ContactPriority.high},
        alertedContactPhones = alertedContactPhones ?? {};

  final String sosDocId;
  final String userId;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final DateTime startedAt;

  ContactPriority currentLevel;
  bool isResolved;
  DateTime? resolvedAt;

  /// Tracks which priority tiers have already been alerted.
  final Set<ContactPriority> alertedPriorities;

  /// Tracks normalized phone numbers that have already received/opened an alert.
  final Set<String> alertedContactPhones;

  Duration get elapsed => DateTime.now().difference(startedAt);

  bool get isHighAlerted => alertedPriorities.contains(ContactPriority.high);
  bool get isMediumAlerted =>
      alertedPriorities.contains(ContactPriority.medium);
  bool get isLowAlerted => alertedPriorities.contains(ContactPriority.low);
}

// ─────────────────────────────────────────────────────────────────────────────
// SosEscalationProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Single source of truth for active SOS escalation sessions.
///
/// Features:
/// - Anchors escalation timeline to the original SOS timestamp (T=0, T=2m, T=5m).
/// - Prevents duplicate conflicting escalation sessions on rapid triggers.
/// - Manages safety check prompts at T=2m and T=5m.
/// - Coordinates escalation writes with [SosRepository] and [ActivityRepository].
/// - Handles instant "I'm Safe" resolution.
class SosEscalationProvider extends ChangeNotifier {
  SosEscalationProvider({
    SosRepository? sosRepository,
    ActivityRepository? activityRepository,
  })  : _sosRepo = sosRepository ?? SosRepository(),
        _activityRepo = activityRepository ?? ActivityRepository();

  final SosRepository _sosRepo;
  final ActivityRepository _activityRepo;

  // ── State ───────────────────────────────────────────────────────────────────

  ActiveSosSession? _activeSession;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  bool _isSafetyCheckPending = false;
  ContactPriority? _pendingEscalationPriority;

  // ── Getters ─────────────────────────────────────────────────────────────────

  ActiveSosSession? get activeSession => _activeSession;
  bool get hasActiveSession =>
      _activeSession != null && !_activeSession!.isResolved;
  Duration get elapsed => _elapsed;
  bool get isSafetyCheckPending => _isSafetyCheckPending;
  ContactPriority? get pendingEscalationPriority => _pendingEscalationPriority;

  // ── Session Lifecycle ───────────────────────────────────────────────────────

  /// Starts a new SOS escalation session or safely joins an existing active session.
  ActiveSosSession startSession({
    required String sosDocId,
    required String userId,
    required double latitude,
    required double longitude,
    required String mapsUrl,
    DateTime? startedAt,
  }) {
    // If a session is already active and unresolved, do NOT create a conflicting timer.
    if (_activeSession != null && !_activeSession!.isResolved) {
      debugPrint(
        'ℹ️ SosEscalationProvider: Joining existing active SOS session (${_activeSession!.sosDocId})',
      );
      return _activeSession!;
    }

    final startTime = startedAt ?? DateTime.now();
    _activeSession = ActiveSosSession(
      sosDocId: sosDocId,
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      mapsUrl: mapsUrl,
      startedAt: startTime,
      currentLevel: ContactPriority.high,
      alertedPriorities: {ContactPriority.high},
    );

    _elapsed = Duration.zero;
    _isSafetyCheckPending = false;
    _pendingEscalationPriority = null;

    _startTicker();
    notifyListeners();
    return _activeSession!;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSession == null || _activeSession!.isResolved) {
        _ticker?.cancel();
        return;
      }

      _elapsed = _activeSession!.elapsed;
      _checkEscalationThresholds();
      notifyListeners();
    });
  }

  void _checkEscalationThresholds() {
    final session = _activeSession;
    if (session == null || session.isResolved) return;

    final seconds = _elapsed.inSeconds;

    // T = 2 minutes (120s): Prompt safety check for Medium Priority
    if (seconds >= 120 && !session.isMediumAlerted) {
      if (!_isSafetyCheckPending &&
          _pendingEscalationPriority != ContactPriority.medium) {
        debugPrint('🚨 SosEscalationProvider: T=2m reached. Safety check for Medium priority.');
        _isSafetyCheckPending = true;
        _pendingEscalationPriority = ContactPriority.medium;
      }
    }

    // T = 5 minutes (300s): Prompt safety check for Low Priority
    if (seconds >= 300 && !session.isLowAlerted) {
      if (!_isSafetyCheckPending &&
          _pendingEscalationPriority != ContactPriority.low) {
        debugPrint('🚨 SosEscalationProvider: T=5m reached. Safety check for Low priority.');
        _isSafetyCheckPending = true;
        _pendingEscalationPriority = ContactPriority.low;
      }
    }
  }

  // ── Escalation Actions ─────────────────────────────────────────────────────

  /// Confirms that the user is still in danger and executes the pending escalation tier.
  Future<void> confirmStillInDanger() async {
    final priority = _pendingEscalationPriority;
    _isSafetyCheckPending = false;
    _pendingEscalationPriority = null;

    if (priority != null && _activeSession != null) {
      await escalateTo(priority);
    }
    notifyListeners();
  }

  /// Manually escalates to a specific [priority] level.
  Future<void> escalateTo(ContactPriority priority) async {
    final session = _activeSession;
    if (session == null || session.isResolved) return;

    session.alertedPriorities.add(priority);
    session.currentLevel = priority;
    _isSafetyCheckPending = false;
    _pendingEscalationPriority = null;

    try {
      await _sosRepo.updateEscalationLevel(
        session.sosDocId,
        level: priority.value,
        alertedAt: DateTime.now(),
      );

      await _activityRepo.logActivity(
        uid: session.userId,
        type: ActivityLogType.locationShared,
        description: 'SOS escalated to ${priority.displayLabel}.',
      );
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider.escalateTo Firestore update failed: $e');
    }

    notifyListeners();
  }

  /// Marks the active emergency as resolved and cancels all escalation timers.
  Future<bool> resolveEmergency() async {
    final session = _activeSession;
    if (session == null) return true;

    _ticker?.cancel();
    session.isResolved = true;
    session.resolvedAt = DateTime.now();
    _isSafetyCheckPending = false;
    _pendingEscalationPriority = null;
    notifyListeners();

    try {
      await _sosRepo.updateStatus(session.sosDocId, SosStatus.resolved);
      await _activityRepo.logActivity(
        uid: session.userId,
        type: ActivityLogType.locationShared,
        description: 'SOS emergency resolved by user.',
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider.resolveEmergency Firestore update failed: $e');
      return false;
    }
  }

  /// Records that SMS was opened/sent for a specific contact phone number.
  void recordContactAlerted(String phone) {
    if (_activeSession == null) return;
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    _activeSession!.alertedContactPhones.add(normalized);
    notifyListeners();
  }

  /// Checks if a contact's phone has already been alerted in this active session.
  bool isContactAlerted(String phone) {
    if (_activeSession == null) return false;
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return _activeSession!.alertedContactPhones.contains(normalized);
  }

  /// Dismisses the safety check modal temporarily.
  void dismissSafetyCheck() {
    _isSafetyCheckPending = false;
    notifyListeners();
  }

  /// Clears the session entirely (e.g. on logout or fresh start).
  void clearSession() {
    _ticker?.cancel();
    _activeSession = null;
    _elapsed = Duration.zero;
    _isSafetyCheckPending = false;
    _pendingEscalationPriority = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
