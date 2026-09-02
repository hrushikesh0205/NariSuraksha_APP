import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContactProvider
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the list of emergency contacts for the authenticated user.
///
/// Subscribes to [ContactRepository.watchContacts] for real-time updates.
/// Delegates all writes to [ContactRepository] and logs activity via
/// [ActivityRepository].
class ContactProvider extends ChangeNotifier {
  ContactProvider({
    ContactRepository? contactRepository,
    ActivityRepository? activityRepository,
  })  : _contactRepo = contactRepository ?? ContactRepository(),
        _activityRepo = activityRepository ?? ActivityRepository();

  final ContactRepository _contactRepo;
  final ActivityRepository _activityRepo;

  // ── State ───────────────────────────────────────────────────────────────────

  List<EmergencyContact> _contacts = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  StreamSubscription<List<EmergencyContact>>? _sub;
  String? _currentUid;

  // ── Getters ─────────────────────────────────────────────────────────────────

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);
  int get count => _contacts.length;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  bool get hasReachedLimit => _contacts.length >= 5;

  /// Returns all High Priority contacts (T = 0 immediate alert).
  List<EmergencyContact> get highPriorityContacts =>
      _contacts.where((c) => c.priority == ContactPriority.high).toList();

  /// Returns all Medium Priority contacts (T = 2 min escalation).
  List<EmergencyContact> get mediumPriorityContacts =>
      _contacts.where((c) => c.priority == ContactPriority.medium).toList();

  /// Returns all Low Priority contacts (T = 5 min escalation).
  List<EmergencyContact> get lowPriorityContacts =>
      _contacts.where((c) => c.priority == ContactPriority.low).toList();

  /// Returns all contacts matching a given [priority].
  List<EmergencyContact> contactsByPriority(ContactPriority priority) =>
      _contacts.where((c) => c.priority == priority).toList();

  // ── Subscription ────────────────────────────────────────────────────────────

  /// Starts listening to the contact stream for [uid].
  ///
  /// Safe to call multiple times — only subscribes once per uid.
  void subscribe(String uid) {
    debugPrint('[ContactProvider] subscribe called for uid: $uid');
    if (_currentUid == uid && _sub != null) return;
    _currentUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _sub?.cancel();
    _sub = _contactRepo.watchContacts(uid).listen(
      (list) {
        debugPrint('[ContactProvider] Received ${list.length} contacts for uid: $uid');
        _contacts = list;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('🔥 [ContactProvider] Error in watchContacts stream: $e');
        _isLoading = false;
        _errorMessage = _friendlyError(e);
        notifyListeners();
      },
    );
  }

  /// Cancels the Firestore stream.
  void unsubscribe() {
    _sub?.cancel();
    _sub = null;
    _currentUid = null;
    _contacts = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ── CREATE ──────────────────────────────────────────────────────────────────

  /// Adds a new contact to Firestore.
  ///
  /// Returns `null` on success, or an error string to display in the UI.
  Future<String?> addContact({
    required String uid,
    required String name,
    required String phone,
    required String relation,
    ContactPriority priority = ContactPriority.high,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final contact = EmergencyContact(
        userId: uid,
        name: name.trim(),
        phone: phone.trim(),
        relation: relation.trim(),
        priority: priority,
      );
      await _contactRepo.addContact(uid, contact);
      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.contactAdded,
        description: 'Emergency contact "${name.trim()}" (${priority.displayLabel}) was added.',
      );
      return null; // success
    } on ContactLimitException catch (e) {
      return e.message;
    } on DuplicatePhoneException catch (e) {
      return e.message;
    } catch (e) {
      return _friendlyError(e);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────────

  /// Updates an existing contact.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> editContact({
    required String uid,
    required EmergencyContact contact,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _contactRepo.updateContact(uid, contact);
      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.profileUpdated,
        description: 'Emergency contact "${contact.name}" was updated.',
      );
      return null;
    } on DuplicatePhoneException catch (e) {
      return e.message;
    } catch (e) {
      return _friendlyError(e);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── DELETE ──────────────────────────────────────────────────────────────────

  /// Permanently deletes a contact after Firestore deletion completes.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> deleteContact({
    required String uid,
    required EmergencyContact contact,
  }) async {
    final id = contact.id;
    if (id == null || id.isEmpty) {
      debugPrint('[ContactProvider] deleteContact error: contact.id is null or empty');
      return 'Cannot delete contact: missing contact ID.';
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[ContactProvider] Initiating deletion for contact "${contact.name}" (ID: $id) for user $uid');
      // 1. Delete document from Firestore first (wait for successful completion)
      await _contactRepo.deleteContact(uid, id);

      // 2. Update local provider state only after Firestore delete succeeds
      _contacts = _contacts.where((c) => c.id != id).toList();

      // 3. Log activity
      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.contactDeleted,
        description: 'Emergency contact "${contact.name}" was removed.',
      );

      debugPrint('[ContactProvider] Deletion complete. Remaining contacts: ${_contacts.length}');
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[ContactProvider] Deletion aborted due to error: $e');
      final errorMsg = _friendlyError(e);
      _errorMessage = errorMsg;
      // Do not remove contact from _contacts list if deletion failed
      notifyListeners();
      return errorMsg;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _friendlyError(Object e) {
    debugPrint('🔥 [ContactProvider] _friendlyError raw: $e');

    // ── Handle Firestore-specific error codes directly ──────────────────────
    if (e is FirebaseException) {
      debugPrint('🔥 [ContactProvider] FirebaseException code: ${e.code}, message: ${e.message}');
      switch (e.code) {
        case 'unauthenticated':
          return 'You are not signed in. Please sign in again.';
        case 'permission-denied':
          return 'Firestore permission denied (${e.code}). Please verify Firestore security rules on Firebase Console.';
        case 'unavailable':
        case 'resource-exhausted':
          return 'You are offline. Please check your internet connection.';
        case 'not-found':
          return 'The requested contact document was not found in Firestore.';
        case 'deadline-exceeded':
          return 'The request timed out. Please try again.';
        default:
          return 'Firestore error [${e.code}]: ${e.message ?? 'Unknown error'}';
      }
    }

    // ── String-based fallback for wrapped/rethrown errors ───────────────────
    final msg = e.toString();
    final lower = msg.toLowerCase();
    debugPrint('🔥 [ContactProvider] _friendlyError fallback mapping: $lower');
    if (lower.contains('unauthenticated') || lower.contains('not signed in')) {
      return 'You are not signed in. Please sign in again.';
    }
    if (lower.contains('network') || lower.contains('unavailable') || lower.contains('offline')) {
      return 'You are offline. Please check your internet connection.';
    }
    if (lower.contains('permission-denied') || lower.contains('permission_denied')) {
      return 'Firestore permission denied. Please verify Firestore security rules on Firebase Console.';
    }
    return msg.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
