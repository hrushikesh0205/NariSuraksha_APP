/// SOS service — encapsulates trigger/stop logic and all user-facing message
/// strings related to emergency actions.
///
/// Currently stateless; in a production build this would integrate with
/// background isolates, platform channels, and real GPS/SMS APIs.
abstract final class SosService {
  // ── State Helpers ───────────────────────────────────────────────────────────

  /// Toggles the SOS active state.
  ///
  /// Returns `true` when activating, `false` when deactivating.
  static bool toggle(bool currentState) => !currentState;

  // ── User-Facing Messages ────────────────────────────────────────────────────

  /// Shown in a snackbar when SOS is activated.
  static const String activatedMessage =
      '🚨 EMERGENCY ACTIVATED! Broadcasting location and alerting guardians...';

  /// Shown in a snackbar when SOS is deactivated.
  static const String deactivatedMessage =
      '✅ Emergency standby mode restored.';

  /// Shown when the "Call Police" quick action is tapped.
  static const String callPoliceMessage =
      '📞 Launching native phone dialer: Calling 100...';

  /// Shown when the "Contacts" quick action is tapped.
  static const String openContactsMessage =
      '👉 Tap "Guardians" in the bottom dock to manage numbers!';

  /// Shown when the "Location" quick action is tapped.
  static const String locationMessage =
      '📍 GPS Verified: Coordinates locking onto your local region...';
}
