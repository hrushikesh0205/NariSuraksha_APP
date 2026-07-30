import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActivityLogType
// ─────────────────────────────────────────────────────────────────────────────

/// Supported activity event types for the Recent Alerts feed.
///
/// Named [ActivityLogType] (not ActivityType) to avoid conflict with
/// `package:geolocator_apple` which also exports an `ActivityType`.
enum ActivityLogType {
  sosActivated,
  locationShared,
  contactAdded,
  timerCompleted,
  timerStarted,
  profileUpdated,
  unknown;

  static ActivityLogType fromString(String? value) {
    switch (value) {
      case 'sos_activated':
        return ActivityLogType.sosActivated;
      case 'location_shared':
        return ActivityLogType.locationShared;
      case 'contact_added':
        return ActivityLogType.contactAdded;
      case 'timer_completed':
        return ActivityLogType.timerCompleted;
      case 'timer_started':
        return ActivityLogType.timerStarted;
      case 'profile_updated':
        return ActivityLogType.profileUpdated;
      default:
        return ActivityLogType.unknown;
    }
  }

  String get value {
    switch (this) {
      case ActivityLogType.sosActivated:
        return 'sos_activated';
      case ActivityLogType.locationShared:
        return 'location_shared';
      case ActivityLogType.contactAdded:
        return 'contact_added';
      case ActivityLogType.timerCompleted:
        return 'timer_completed';
      case ActivityLogType.timerStarted:
        return 'timer_started';
      case ActivityLogType.profileUpdated:
        return 'profile_updated';
      case ActivityLogType.unknown:
        return 'unknown';
    }
  }

  String get displayLabel {
    switch (this) {
      case ActivityLogType.sosActivated:
        return 'SOS Activated';
      case ActivityLogType.locationShared:
        return 'Location Shared';
      case ActivityLogType.contactAdded:
        return 'Contact Added';
      case ActivityLogType.timerCompleted:
        return 'Timer Completed';
      case ActivityLogType.timerStarted:
        return 'Timer Started';
      case ActivityLogType.profileUpdated:
        return 'Profile Updated';
      case ActivityLogType.unknown:
        return 'Activity';
    }
  }
}

/// A single activity log entry stored in Firestore.
///
/// Firestore path: `activity_logs/{docId}`
///
/// Used to populate the "Recent Alerts" section on the Home Dashboard.
@immutable
class ActivityLogModel {
  /// Firestore document ID.
  final String? id;

  /// UID of the user this log belongs to.
  final String userId;

  /// Categorised event type.
  final ActivityLogType type;

  /// Human-readable description shown in the UI.
  final String description;

  /// When the activity occurred.
  final DateTime timestamp;

  const ActivityLogModel({
    this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  // ── Factories ───────────────────────────────────────────────────────────────

  factory ActivityLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ActivityLogModel(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      type: ActivityLogType.fromString(data['type'] as String?),
      description: (data['description'] as String?) ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.value,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  ActivityLogModel copyWith({
    String? id,
    String? userId,
    ActivityLogType? type,
    String? description,
    DateTime? timestamp,
  }) {
    return ActivityLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() =>
      'ActivityLogModel(type: ${type.value}, description: $description)';
}
