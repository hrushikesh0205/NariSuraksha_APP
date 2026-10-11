import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SosStatus
// ─────────────────────────────────────────────────────────────────────────────

/// Status values for a SOS alert.
enum SosStatus {
  active,
  resolved,
  cancelled;

  static SosStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'resolved':
        return SosStatus.resolved;
      case 'cancelled':
        return SosStatus.cancelled;
      default:
        return SosStatus.active;
    }
  }

  String get value => name; // 'active' | 'resolved' | 'cancelled'
}

// ─────────────────────────────────────────────────────────────────────────────
// SosRecordModel
// ─────────────────────────────────────────────────────────────────────────────

/// A single SOS alert record stored in Firestore with priority escalation metadata.
///
/// Firestore path: `sos_history/{docId}`
@immutable
class SosRecordModel {
  /// The Firestore document ID (auto-generated).
  final String? id;

  /// UID of the user who triggered the SOS.
  final String userId;

  /// WGS-84 latitude of the SOS location.
  final double latitude;

  /// WGS-84 longitude of the SOS location.
  final double longitude;

  /// When the SOS was originally triggered (anchors all escalation timing).
  final DateTime timestamp;

  /// Current status of this SOS alert (active / resolved / cancelled).
  final SosStatus status;

  /// Current escalation level reached ('high' | 'medium' | 'low').
  final String escalationLevel;

  /// Timestamp when the emergency was resolved.
  final DateTime? resolvedAt;

  /// Timestamp when High Priority contacts were alerted (T = 0).
  final DateTime? highAlertedAt;

  /// Timestamp when Medium Priority contacts were alerted (T = 2 min).
  final DateTime? mediumAlertedAt;

  /// Timestamp when Low Priority contacts were alerted (T = 5 min).
  final DateTime? lowAlertedAt;

  /// How the SOS was triggered ('button' | 'voice' | 'shake').
  final String triggerSource;

  /// Whether the user authorized calling police/100 at worst-case stage.
  /// `null` = not yet prompted, `true` = authorized, `false` = declined.
  final bool? policeCallAuthorized;

  /// Per-contact SMS result map: normalised phone → result string.
  /// Possible values: 'sent', 'failed', 'pending', 'skipped'.
  final Map<String, String>? smsResults;

  const SosRecordModel({
    this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = SosStatus.active,
    this.escalationLevel = 'high',
    this.resolvedAt,
    this.highAlertedAt,
    this.mediumAlertedAt,
    this.lowAlertedAt,
    this.triggerSource = 'button',
    this.policeCallAuthorized,
    this.smsResults,
  });

  // ── Factories ───────────────────────────────────────────────────────────────

  factory SosRecordModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SosRecordModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
          (data['startedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      status: SosStatus.fromString(data['status'] as String?),
      escalationLevel: (data['escalationLevel'] as String?) ?? 'high',
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      highAlertedAt: (data['highAlertedAt'] as Timestamp?)?.toDate(),
      mediumAlertedAt: (data['mediumAlertedAt'] as Timestamp?)?.toDate(),
      lowAlertedAt: (data['lowAlertedAt'] as Timestamp?)?.toDate(),
      triggerSource: (data['triggerSource'] as String?) ?? 'button',
      policeCallAuthorized: data['policeCallAuthorized'] as bool?,
      smsResults: (data['smsResults'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'status': status.value,
      'escalationLevel': escalationLevel,
      'triggerSource': triggerSource,
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (highAlertedAt != null)
        'highAlertedAt': Timestamp.fromDate(highAlertedAt!),
      if (mediumAlertedAt != null)
        'mediumAlertedAt': Timestamp.fromDate(mediumAlertedAt!),
      if (lowAlertedAt != null) 'lowAlertedAt': Timestamp.fromDate(lowAlertedAt!),
      if (policeCallAuthorized != null)
        'policeCallAuthorized': policeCallAuthorized,
      if (smsResults != null) 'smsResults': smsResults,
    };
  }

  SosRecordModel copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    SosStatus? status,
    String? escalationLevel,
    DateTime? resolvedAt,
    DateTime? highAlertedAt,
    DateTime? mediumAlertedAt,
    DateTime? lowAlertedAt,
    String? triggerSource,
    bool? policeCallAuthorized,
    Map<String, String>? smsResults,
  }) {
    return SosRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      highAlertedAt: highAlertedAt ?? this.highAlertedAt,
      mediumAlertedAt: mediumAlertedAt ?? this.mediumAlertedAt,
      lowAlertedAt: lowAlertedAt ?? this.lowAlertedAt,
      triggerSource: triggerSource ?? this.triggerSource,
      policeCallAuthorized: policeCallAuthorized ?? this.policeCallAuthorized,
      smsResults: smsResults ?? this.smsResults,
    );
  }

  @override
  String toString() =>
      'SosRecordModel(id: $id, userId: $userId, lat: $latitude, lng: $longitude, status: ${status.value}, level: $escalationLevel)';
}
