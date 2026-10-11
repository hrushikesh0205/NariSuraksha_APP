import 'package:drift/drift.dart';

// -----------------------------------------------------------------------------
// LocalSosHistoryTable
// -----------------------------------------------------------------------------

/// Stores SOS history records locally for offline-first SOS history.
///
/// Records start with syncStatus = 'pending'.
/// After successful Firestore upload, syncStatus = 'synced'.
/// The firestoreDocId is populated after successful sync.
class LocalSosHistoryTable extends Table {
  /// Stable local ID (UUID generated at SOS time, used as Firestore doc ID).
  TextColumn get localId => text()();

  /// Firestore document ID after sync (null until synced).
  TextColumn get firestoreDocId => text().nullable()();

  /// UID of the user who triggered the SOS.
  TextColumn get userId => text()();

  /// WGS-84 latitude.
  RealColumn get latitude => real().withDefault(const Constant(0.0))();

  /// WGS-84 longitude.
  RealColumn get longitude => real().withDefault(const Constant(0.0))();

  /// ISO 8601 SOS start timestamp.
  TextColumn get startedAt => text()();

  /// SOS status: 'active' | 'resolved' | 'cancelled'
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Escalation level reached: 'high' | 'medium' | 'low'
  TextColumn get escalationLevel => text().withDefault(const Constant('high'))();

  /// ISO 8601 timestamp of resolution (nullable).
  TextColumn get resolvedAt => text().nullable()();

  /// ISO 8601 timestamp when High contacts were alerted.
  TextColumn get highAlertedAt => text().nullable()();

  /// ISO 8601 timestamp when Medium contacts were alerted.
  TextColumn get mediumAlertedAt => text().nullable()();

  /// ISO 8601 timestamp when Low contacts were alerted.
  TextColumn get lowAlertedAt => text().nullable()();

  /// Trigger source: 'button' | 'voice' | 'shake'
  TextColumn get triggerSource => text().withDefault(const Constant('button'))();

  /// JSON string of SMS results map: {phone: 'sent'|'failed'|...}
  TextColumn get smsResultsJson => text().nullable()();

  /// Whether user authorized calling police (null / true / false).
  BoolColumn get policeCallAuthorized => boolean().nullable()();

  /// Sync status: 'pending' | 'synced'
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {localId};
}
