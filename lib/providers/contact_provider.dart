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
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final contact = EmergencyContact(
        userId: uid,
        name: name.trim(),
        phone: phone.trim(),
        relation: relation.trim(),
      );
      await _contactRepo.addContact(uid, contact);
      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.contactAdded,
        description: 'Emergency contact "${name.trim()}" was added.',
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

  /// Permanently deletes a contact.
  ///
  /// Returns `null` on success, or an error string.
  Future<String?> deleteContact({
    required String uid,
    required EmergencyContact contact,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      await _contactRepo.deleteContact(uid, contact.id!);
      await _activityRepo.logActivity(
        uid: uid,
        type: ActivityLogType.contactDeleted,
        description: 'Emergency contact "${contact.name}" was removed.',
      );
      return null;
    } catch (e) {
      return _friendlyError(e);
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
      debugPrint('🔥 [ContactProvider] FirebaseException code: ${e.code}');
      switch (e.code) {
        case 'unauthenticated':
          return 'You are not signed in. Please sign in again.';
        case 'permission-denied':
          return 'Firestore permission denied. Please contact support.';
        case 'unavailable':
        case 'resource-exhausted':
          return 'You are offline. Please check your internet connection.';
        case 'not-found':
          return 'The requested data was not found.';
        case 'deadline-exceeded':
          return 'The request timed out. Please try again.';
        default:
          return 'Something went wrong (${e.code}). Please try again.';
      }
    }

    // ── String-based fallback for wrapped/rethrown errors ───────────────────
    final msg = e.toString().toLowerCase();
    debugPrint('🔥 [ContactProvider] _friendlyError mapping: $msg');
    if (msg.contains('unauthenticated') || msg.contains('not signed in')) {
      return 'You are not signed in. Please sign in again.';
    }
    if (msg.contains('network') || msg.contains('unavailable') || msg.contains('offline')) {
      return 'You are offline. Please check your internet connection.';
    }
    if (msg.contains('permission-denied') || msg.contains('permission_denied')) {
      return 'Firestore permission denied. Please contact support.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
