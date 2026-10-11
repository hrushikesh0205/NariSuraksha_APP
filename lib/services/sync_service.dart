import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';
import 'package:nari_suraksha/repositories/local_contact_repository.dart';
import 'package:nari_suraksha/repositories/local_sos_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SyncService
// ─────────────────────────────────────────────────────────────────────────────

/// Synchronizes local SQLite data ↔ Firestore when connectivity is restored.
///
/// Triggered by [ConnectivityProvider] when network becomes available.
/// All operations are safe to call multiple times (idempotent).
class SyncService {
  SyncService({
    AuthService? authService,
    ContactRepository? contactRepository,
    LocalContactRepository? localContactRepository,
    SosRepository? sosRepository,
    LocalSosRepository? localSosRepository,
  })  : _authService = authService ?? AuthService(),
        _contactRepository = contactRepository ?? ContactRepository(),
        _localContactRepository =
            localContactRepository ?? LocalContactRepository(),
        _sosRepository = sosRepository ?? SosRepository(),
        _localSosRepository = localSosRepository ?? LocalSosRepository();

  final AuthService _authService;
  final ContactRepository _contactRepository;
  final LocalContactRepository _localContactRepository;
  final SosRepository _sosRepository;
  final LocalSosRepository _localSosRepository;

  bool _isSyncing = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Runs a full sync cycle:
  /// 1. Download fresh contacts from Firestore → local DB.
  /// 2. Upload PENDING_SYNC SOS history → Firestore.
  ///
  /// Safe to call concurrently — skips if already running.
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('ℹ️ SyncService: sync already in progress — skipping');
      return;
    }

    final uid = _authService.firebaseUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('ℹ️ SyncService: no user — skipping sync');
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 SyncService: starting sync for uid=$uid');

    try {
      await Future.wait([
        _syncContactsFromFirestore(uid),
        _uploadPendingSosHistory(uid),
      ]);
      debugPrint('✅ SyncService: sync complete');
    } catch (e) {
      debugPrint('⚠️ SyncService.syncAll error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ── Contacts Sync ─────────────────────────────────────────────────────────

  /// Downloads contacts from Firestore and replaces the local cache.
  Future<void> _syncContactsFromFirestore(String uid) async {
    try {
      final contacts = await _contactRepository.getContacts(uid);
      await _localContactRepository.replaceAll(uid, contacts);
      debugPrint(
          '📦 SyncService: synced ${contacts.length} contacts from Firestore');
    } catch (e) {
      debugPrint('⚠️ SyncService._syncContactsFromFirestore error: $e');
    }
  }

  // ── SOS History Upload ────────────────────────────────────────────────────

  /// Uploads PENDING_SYNC SOS history records to Firestore.
  Future<void> _uploadPendingSosHistory(String uid) async {
    try {
      final pending =
          await _localSosRepository.getPendingHistoryRecords(uid);

      if (pending.isEmpty) {
        debugPrint('📦 SyncService: no pending SOS records to upload');
        return;
      }

      debugPrint(
          '📦 SyncService: uploading ${pending.length} pending SOS records');

      for (final row in pending) {
        try {
          // Build Firestore record from local data.
          final record = SosRecordModel(
            userId: row.userId,
            latitude: row.latitude,
            longitude: row.longitude,
            timestamp: DateTime.tryParse(row.startedAt) ?? DateTime.now(),
            status: _parseStatus(row.status),
            escalationLevel: row.escalationLevel,
            resolvedAt: row.resolvedAt != null
                ? DateTime.tryParse(row.resolvedAt!)
                : null,
            highAlertedAt: row.highAlertedAt != null
                ? DateTime.tryParse(row.highAlertedAt!)
                : null,
            mediumAlertedAt: row.mediumAlertedAt != null
                ? DateTime.tryParse(row.mediumAlertedAt!)
                : null,
            lowAlertedAt: row.lowAlertedAt != null
                ? DateTime.tryParse(row.lowAlertedAt!)
                : null,
          );

          // Use localId as the Firestore document ID for deduplication.
          final firestoreDocId = await _sosRepository.createSosRecord(record,
              docId: row.localId);

          // Mark as synced in local DB.
          await _localSosRepository.markHistorySynced(
              row.localId, firestoreDocId);

          debugPrint(
              '✅ SyncService: uploaded SOS ${row.localId} as $firestoreDocId');
        } on FirebaseException catch (fe) {
          // Already-exists error means a previous sync uploaded it → mark synced.
          if (fe.code == 'already-exists') {
            await _localSosRepository.markHistorySynced(
                row.localId, row.localId);
            debugPrint(
                'ℹ️ SyncService: SOS ${row.localId} already in Firestore — marking synced');
          } else {
            debugPrint(
                '⚠️ SyncService: Firestore error for ${row.localId}: ${fe.message}');
          }
        } catch (e) {
          debugPrint(
              '⚠️ SyncService: error uploading SOS ${row.localId}: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ SyncService._uploadPendingSosHistory error: $e');
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  SosStatus _parseStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'resolved':
        return SosStatus.resolved;
      case 'cancelled':
        return SosStatus.cancelled;
      default:
        return SosStatus.active;
    }
  }
}
