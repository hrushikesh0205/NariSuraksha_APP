import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsService
// ─────────────────────────────────────────────────────────────────────────────

/// Builds emergency SMS messages and opens the Android SMS composer.
///
/// Uses the `sms:` URI scheme via [url_launcher] — this opens the device's
/// native SMS app with the recipient and message pre-filled. The user taps
/// Send manually, which avoids requiring the SEND_SMS permission.
class SmsService {
  const SmsService();

  // ── Message building ────────────────────────────────────────────────────────

  /// Constructs a professional emergency alert message.
  ///
  /// [userName]  — The authenticated user's display name (or 'A Nari Suraksha user').
  /// [mapsUrl]   — Google Maps URL with real GPS coordinates.
  /// [timestamp] — The exact time of the SOS alert.
  String buildEmergencyMessage({
    required String userName,
    required String mapsUrl,
    required DateTime timestamp,
  }) {
    final timeStr = _formatTimestamp(timestamp);
    return '''🚨 EMERGENCY ALERT – Nari Suraksha

$userName may be in danger and has triggered an SOS alert.

📍 Current Location:
$mapsUrl

⏰ Time: $timeStr

Please contact them immediately or call emergency services (Police: 100, Ambulance: 108) if required.

– Sent via Nari Suraksha Safety App''';
  }

  /// Formats a [DateTime] as a human-readable timestamp.
  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$hour:$minute $period, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ── Phone normalisation ─────────────────────────────────────────────────────

  /// Strips formatting characters from [phone] while preserving a leading `+`.
  ///
  /// Examples:
  ///   '+91 98765 43210' → '+919876543210'
  ///   '98765-43210'     → '9876543210'
  ///   ''                → ''
  String normalizePhone(String phone) {
    final trimmed = phone.trim();
    final hasPlus = trimmed.startsWith('+');
    // Remove everything except digits.
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  /// Returns `true` when [phone] looks like a plausible mobile number.
  bool isValidPhone(String phone) {
    final normalized = normalizePhone(phone);
    // Accept 7–15 digits, optionally prefixed with '+'.
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalized);
  }

  // ── SMS composer ────────────────────────────────────────────────────────────

  /// Opens the device's SMS composer with [phone] as recipient and
  /// [message] as the body.
  ///
  /// Returns `true` if the SMS app was launched successfully.
  Future<bool> openSmsComposer({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) {
      debugPrint('[SmsService] openSmsComposer: empty phone after normalisation.');
      return false;
    }

    // Android: sms:PHONE?body=MESSAGE
    // iOS:     sms:PHONE&body=MESSAGE  (different separator)
    final uri = Uri(
      scheme: 'sms',
      path: normalized,
      queryParameters: {'body': message},
    );

    debugPrint('[SmsService] Attempting to launch SMS URI for: $normalized');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('[SmsService] launchUrl result: $launched');
      return launched;
    } catch (e) {
      debugPrint('[SmsService] launchUrl error: $e');
      return false;
    }
  }
}
