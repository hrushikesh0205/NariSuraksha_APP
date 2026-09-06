import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';
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
    this.triggerSource = 'button',
    Set<ContactPriority>? alertedPriorities,
    Set<String>? alertedContactPhones,
    Map<String, SmsResult>? smsResultsMap,
  })  : alertedPriorities = alertedPriorities ?? {ContactPriority.high},
        alertedContactPhones = alertedContactPhones ?? {},
        smsResultsMap = smsResultsMap ?? {};

  final String sosDocId;
  final String userId;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final DateTime startedAt;
  final String triggerSource;

  ContactPriority currentLevel;
  bool isResolved;
  DateTime? resolvedAt;

  /// Tracks which priority tiers have already been alerted.
  final Set<ContactPriority> alertedPriorities;

  /// Tracks normalized phone numbers that have already received/opened an alert.
  final Set<String> alertedContactPhones;

  /// Per-contact SMS result tracking: normalised phone → result.
  final Map<String, SmsResult> smsResultsMap;

  Duration get elapsed => DateTime.now().difference(startedAt);

  bool get isHighAlerted => alertedPriorities.contains(ContactPriority.high);
  bool get isMediumAlerted =>
      alertedPriorities.contains(ContactPriority.medium);
  bool get isLowAlerted => alertedPriorities.contains(ContactPriority.low);

  /// Whether police/112 confirmation is pending.
  bool policeConfirmationPending = false;

  /// Whether the user already responded to the police prompt.
  bool? policeCallAuthorized;
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
/// - Automatically sends SMS to contacts via native Android SmsManager.
/// - Handles police confirmation at worst-case stage.
/// - Handles instant "I'm Safe" resolution.
class SosEscalationProvider extends ChangeNotifier {
  SosEscalationProvider({
    SosRepository? sosRepository,
    ActivityRepository? activityRepository,
    ContactRepository? contactRepository,
    SmsService? smsService,
  })  : _sosRepo = sosRepository ?? SosRepository(),
        _activityRepo = activityRepository ?? ActivityRepository(),
        _contactRepo = contactRepository,
        _smsService = smsService ?? const SmsService();

  final SosRepository _sosRepo;
  final ActivityRepository _activityRepo;
  final ContactRepository? _contactRepo;
  final SmsService _smsService;

  // ── Timeline constants (in seconds from startedAt) ──────────────────────────
  static const int mediumThresholdSeconds = 240; // T = 4 minutes
  static const int lowThresholdSeconds = 480;    // T = 8 minutes
  static const int policeThresholdSeconds = 720; // T = 12 minutes
  static const int safetyCheckTimeoutSeconds = 30; // Auto-danger after 30s timeout

  // ── External Dependencies (set via ProxyProvider) ────────────────────────

  /// Contacts list, set externally by the widget tree or ProxyProvider.
  List<EmergencyContact> _contacts = [];
  String _userName = 'A Nari Suraksha user';

  /// Updates the contact list used for auto-SMS dispatch.
  void updateContacts(List<EmergencyContact> contacts) {
    _contacts = contacts;
  }

  /// Updates the user name used in SMS messages.
  void updateUserName(String name) {
    _userName = name;
  }

  // ── State ───────────────────────────────────────────────────────────────────

  ActiveSosSession? _activeSession;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  bool _isSafetyCheckPending = false;
  DateTime? _safetyCheckOpenedAt;
  ContactPriority? _pendingEscalationPriority;

  /// True while SMS is being sent to a batch of contacts.
  bool _isSendingSms = false;

  /// Last batch SMS results (for UI display).
  List<SmsSendResult> _lastSmsResults = [];

  // ── Getters ─────────────────────────────────────────────────────────────────

  ActiveSosSession? get activeSession => _activeSession;
  bool get hasActiveSession =>
      _activeSession != null && !_activeSession!.isResolved;
  Duration get elapsed => _elapsed;
  bool get isSafetyCheckPending => _isSafetyCheckPending;
  ContactPriority? get pendingEscalationPriority => _pendingEscalationPriority;
  bool get isSendingSms => _isSendingSms;
  List<SmsSendResult> get lastSmsResults => _lastSmsResults;

  bool get isPoliceConfirmationPending =>
      _activeSession?.policeConfirmationPending ?? false;

  // ── Session Lifecycle ───────────────────────────────────────────────────────

  /// Starts a new SOS escalation session or safely joins an existing active session.
  ///
  /// At T=0, automatically sends emergency SMS to all HIGH priority contacts.
  ActiveSosSession startSession({
    required String sosDocId,
    required String userId,
    required double latitude,
    required double longitude,
    required String mapsUrl,
    DateTime? startedAt,
    String triggerSource = 'button',
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
      triggerSource: triggerSource,
    );

    _elapsed = Duration.zero;
    _isSafetyCheckPending = false;
    _safetyCheckOpenedAt = null;
    _pendingEscalationPriority = null;

    _startTicker();
    notifyListeners();

    // T=0: Automatically send SMS to HIGH priority contacts
    _autoSendSms(ContactPriority.high);

    return _activeSession!;
  }

  /// Resumes an existing active session loaded from Firestore across app restarts.
  ActiveSosSession? resumeActiveSession(SosRecordModel record) {
    if (_activeSession != null && !_activeSession!.isResolved) {
      return _activeSession;
    }
    if (record.status != SosStatus.active || record.resolvedAt != null) {
      return null;
    }

    final alertedPriorities = <ContactPriority>{ContactPriority.high};
    if (record.mediumAlertedAt != null) {
      alertedPriorities.add(ContactPriority.medium);
    }
    if (record.lowAlertedAt != null) {
      alertedPriorities.add(ContactPriority.low);
    }

    final currentLevel = switch (record.escalationLevel.toLowerCase()) {
      'low' => ContactPriority.low,
      'medium' => ContactPriority.medium,
      _ => ContactPriority.high,
    };

    final alertedPhones = <String>{};
    final smsResultsMap = <String, SmsResult>{};
    if (record.smsResults != null) {
      for (final entry in record.smsResults!.entries) {
        alertedPhones.add(entry.key);
        smsResultsMap[entry.key] = switch (entry.value) {
          'sent' => SmsResult.sent,
          'failed' => SmsResult.failed,
          'skipped' => SmsResult.skipped,
          _ => SmsResult.pending,
        };
      }
    }

    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${record.latitude},${record.longitude}';

    _activeSession = ActiveSosSession(
      sosDocId: record.id ?? '',
      userId: record.userId,
      latitude: record.latitude,
      longitude: record.longitude,
      mapsUrl: mapsUrl,
      startedAt: record.timestamp,
      currentLevel: currentLevel,
      alertedPriorities: alertedPriorities,
      alertedContactPhones: alertedPhones,
      smsResultsMap: smsResultsMap,
      triggerSource: record.triggerSource,
    );
    _activeSession!.policeCallAuthorized = record.policeCallAuthorized;

    _elapsed = _activeSession!.elapsed;
    _isSafetyCheckPending = false;
    _safetyCheckOpenedAt = null;
    _pendingEscalationPriority = null;

    debugPrint(
      'ℹ️ SosEscalationProvider: Resumed active session (${record.id}) started at ${record.timestamp}, elapsed: ${_elapsed.inMinutes}m',
    );

    _startTicker();
    notifyListeners();
    return _activeSession;
  }

  /// Checks Firestore for any active, unresolved SOS session for [uid] and resumes it.
  Future<ActiveSosSession?> checkAndResumeActiveSession(String uid) async {
    if (_activeSession != null && !_activeSession!.isResolved) {
      return _activeSession;
    }
    if (uid.isEmpty) return null;
    try {
      final recents = await _sosRepo.getRecentSos(uid, limit: 1);
      if (recents.isNotEmpty) {
        final latest = recents.first;
        if (latest.status == SosStatus.active && latest.resolvedAt == null) {
          debugPrint(
            'ℹ️ SosEscalationProvider: Found active SOS record in Firestore (${latest.id}). Resuming...',
          );
          return resumeActiveSession(latest);
        }
      }
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider.checkAndResumeActiveSession failed: $e');
    }
    return null;
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

      // Check auto-timeout for unanswered safety check (user in danger)
      if (_isSafetyCheckPending && _safetyCheckOpenedAt != null) {
        final pendingSeconds =
            DateTime.now().difference(_safetyCheckOpenedAt!).inSeconds;
        if (pendingSeconds >= safetyCheckTimeoutSeconds) {
          debugPrint(
            '🚨 SosEscalationProvider: Safety check timed out after ${safetyCheckTimeoutSeconds}s. Treating as in danger.',
          );
          _safetyCheckOpenedAt = null;
          confirmStillInDanger();
        }
      }

      notifyListeners();
    });
  }

  void _checkEscalationThresholds() {
    final session = _activeSession;
    if (session == null || session.isResolved) return;

    final seconds = _elapsed.inSeconds;

    // T = 4 minutes (240s): Prompt safety check for Medium Priority
    if (seconds >= mediumThresholdSeconds && !session.isMediumAlerted) {
      if (!_isSafetyCheckPending &&
          _pendingEscalationPriority != ContactPriority.medium) {
        debugPrint(
          '🚨 SosEscalationProvider: T=4m reached. Safety check for Medium priority.',
        );
        _isSafetyCheckPending = true;
        _safetyCheckOpenedAt = DateTime.now();
        _pendingEscalationPriority = ContactPriority.medium;
      }
    }

    // T = 8 minutes (480s): Prompt safety check for Low Priority
    if (seconds >= lowThresholdSeconds && !session.isLowAlerted) {
      if (!_isSafetyCheckPending &&
          _pendingEscalationPriority != ContactPriority.low) {
        debugPrint(
          '🚨 SosEscalationProvider: T=8m reached. Safety check for Low priority.',
        );
        _isSafetyCheckPending = true;
        _safetyCheckOpenedAt = DateTime.now();
        _pendingEscalationPriority = ContactPriority.low;
      }
    }

    // T = 12 minutes (720s): Prompt final police confirmation
    if (seconds >= policeThresholdSeconds &&
        !session.policeConfirmationPending &&
        session.policeCallAuthorized == null) {
      debugPrint(
        '🚨 SosEscalationProvider: T=12m reached. Police confirmation pending.',
      );
      session.policeConfirmationPending = true;
    }
  }

  // ── Auto-SMS Dispatch ───────────────────────────────────────────────────────

  /// Sends emergency SMS to all contacts of the given [priority] level.
  ///
  /// Uses native Android SmsManager for background sending.
  /// Falls back gracefully if permission is denied or platform unavailable.
  Future<void> _autoSendSms(ContactPriority priority) async {
    final session = _activeSession;
    if (session == null || session.isResolved) return;

    // Ensure contacts are loaded if not previously cached
    if (_contacts.isEmpty) {
      try {
        debugPrint(
          'ℹ️ SosEscalationProvider: Local contacts list empty. Querying ContactRepository for uid: ${session.userId}...',
        );
        final repo = _contactRepo ?? ContactRepository();
        _contacts = await repo.getContacts(session.userId);
      } catch (e) {
        debugPrint(
          '⚠️ SosEscalationProvider: Failed to fetch contacts from repo: $e',
        );
      }
    }

    final contactsForPriority = _contacts
        .where((c) => c.priority == priority)
        .toList();

    session.alertedPriorities.add(priority);

    if (contactsForPriority.isEmpty) {
      debugPrint('ℹ️ SosEscalationProvider: No ${priority.displayLabel} contacts to SMS.');
      return;
    }

    _isSendingSms = true;
    notifyListeners();

    final message = _smsService.buildEmergencyMessage(
      userName: _userName,
      mapsUrl: session.mapsUrl,
      timestamp: session.startedAt,
      priority: priority,
    );

    final results = <SmsSendResult>[];

    for (final contact in contactsForPriority) {
      final normalizedPhone = _smsService.normalizePhone(contact.phone);

      // Skip if already alerted in this session (duplicate prevention across tiers)
      if (session.alertedContactPhones.contains(normalizedPhone)) {
        debugPrint('ℹ️ SosEscalationProvider: Skipping ${contact.name} (already alerted).');
        results.add(SmsSendResult(
          phone: normalizedPhone,
          contactName: contact.name,
          result: SmsResult.skipped,
          error: 'Already alerted',
        ));
        continue;
      }

      // Mark as pending before sending
      session.smsResultsMap[normalizedPhone] = SmsResult.pending;
      notifyListeners();

      final result = await _smsService.sendDirectSms(
        phone: contact.phone,
        message: message,
        contactName: contact.name,
      );

      results.add(result);
      session.smsResultsMap[normalizedPhone] = result.result;

      if (result.result == SmsResult.sent) {
        session.alertedContactPhones.add(normalizedPhone);
        debugPrint('✅ SosEscalationProvider: SMS sent to ${contact.name} ($normalizedPhone)');
      } else {
        debugPrint('⚠️ SosEscalationProvider: SMS to ${contact.name} failed: ${result.error}');
      }
    }

    _lastSmsResults = results;
    _isSendingSms = false;
    notifyListeners();

    // Persist SMS results to Firestore
    _persistSmsResults(session);

    // Log activity
    final sentCount = results.where((r) => r.result == SmsResult.sent).length;
    final totalCount = results.length;

    try {
      await _activityRepo.logActivity(
        uid: session.userId,
        type: ActivityLogType.locationShared,
        description:
            'Emergency SMS sent to $sentCount/$totalCount ${priority.displayLabel} contacts.',
      );
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider: Activity log failed: $e');
    }
  }

  /// Persists the current SMS results map to Firestore.
  Future<void> _persistSmsResults(ActiveSosSession session) async {
    try {
      final firestoreMap = session.smsResultsMap.map(
        (phone, result) => MapEntry(phone, result.name),
      );
      await _sosRepo.updateSmsResults(session.sosDocId, firestoreMap);
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider: Failed to persist SMS results: $e');
    }
  }

  // ── Escalation Actions ─────────────────────────────────────────────────────

  /// Confirms that the user is still in danger and executes the pending escalation tier.
  ///
  /// This automatically sends SMS to the pending priority tier's contacts.
  Future<void> confirmStillInDanger() async {
    final priority = _pendingEscalationPriority;
    _isSafetyCheckPending = false;
    _safetyCheckOpenedAt = null;
    _pendingEscalationPriority = null;

    if (priority != null && _activeSession != null) {
      await escalateTo(priority);
    }
    notifyListeners();
  }

  /// Manually escalates to a specific [priority] level.
  ///
  /// Also triggers auto-SMS to contacts of that priority tier.
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

    // Automatically send SMS to contacts of this escalated priority
    await _autoSendSms(priority);
  }

  // ── Police Confirmation ─────────────────────────────────────────────────────

  /// Records that the user authorized calling police/112.
  Future<void> authorizePoliceCall() async {
    final session = _activeSession;
    if (session == null) return;

    session.policeCallAuthorized = true;
    session.policeConfirmationPending = false;
    notifyListeners();

    try {
      await _sosRepo.updatePoliceCallStatus(
        session.sosDocId,
        authorized: true,
      );
      await _activityRepo.logActivity(
        uid: session.userId,
        type: ActivityLogType.locationShared,
        description: 'User authorized calling emergency police/112.',
      );
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider.authorizePoliceCall failed: $e');
    }
  }

  /// Records that the user declined calling police (and resolves SOS).
  Future<void> declinePoliceCall() async {
    final session = _activeSession;
    if (session == null) return;

    session.policeCallAuthorized = false;
    session.policeConfirmationPending = false;
    notifyListeners();

    try {
      await _sosRepo.updatePoliceCallStatus(
        session.sosDocId,
        authorized: false,
      );
    } catch (e) {
      debugPrint('⚠️ SosEscalationProvider.declinePoliceCall failed: $e');
    }

    // Declining police = user is safe → resolve
    await resolveEmergency();
  }

  // ── Resolution ──────────────────────────────────────────────────────────────

  /// Marks the active emergency as resolved and cancels all escalation timers.
  Future<bool> resolveEmergency() async {
    final session = _activeSession;
    if (session == null) return true;

    _ticker?.cancel();
    session.isResolved = true;
    session.resolvedAt = DateTime.now();
    session.policeConfirmationPending = false;
    _isSafetyCheckPending = false;
    _safetyCheckOpenedAt = null;
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
    _isSendingSms = false;
    _lastSmsResults = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
