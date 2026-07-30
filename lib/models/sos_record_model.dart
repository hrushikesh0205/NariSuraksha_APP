import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SosRecordModel
// ─────────────────────────────────────────────────────────────────────────────

/// Status values for a SOS alert.
enum SosStatus {
  active,
  resolved,
  cancelled;

  static SosStatus fromString(String? value) {
    switch (value) {
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

/// A single SOS alert record stored in Firestore.
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

  /// When the SOS was triggered.
  final DateTime timestamp;

  /// Current status of this SOS alert.
  final SosStatus status;

  const SosRecordModel({
    this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = SosStatus.active,
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
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: SosStatus.fromString(data['status'] as String?),
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status.value,
    };
  }

  SosRecordModel copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    SosStatus? status,
  }) {
    return SosRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'SosRecordModel(userId: $userId, lat: $latitude, lng: $longitude, status: ${status.value})';
}
