import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsResult
// ─────────────────────────────────────────────────────────────────────────────

/// Result of a single SMS send attempt.
enum SmsResult {
  /// SMS was sent successfully via native SmsManager.
  sent,

  /// SMS send failed (permission denied, no service, invalid number, etc.).
  failed,

  /// SMS is queued / pending send.
  pending,

  /// SMS was skipped (invalid phone, already alerted, etc.).
  skipped;

  String get displayLabel {
    switch (this) {
      case SmsResult.sent:
        return 'SMS Sent';
      case SmsResult.failed:
        return 'SMS Failed';
      case SmsResult.pending:
        return 'Pending';
      case SmsResult.skipped:
        return 'Skipped';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SmsSendResult
// ─────────────────────────────────────────────────────────────────────────────

/// Per-contact SMS send result.
class SmsSendResult {
  const SmsSendResult({
    required this.phone,
    required this.contactName,
    required this.result,
    this.error,
  });

  final String phone;
  final String contactName;
  final SmsResult result;
  final String? error;

  @override
  String toString() =>
      'SmsSendResult(phone: $phone, name: $contactName, result: ${result.name}, error: $error)';
}

// ─────────────────────────────────────────────────────────────────────────────
// SmsService
// ─────────────────────────────────────────────────────────────────────────────

/// Builds emergency SMS messages and sends them via native Android SmsManager
/// or falls back to the SMS composer.
///
/// Uses a MethodChannel `com.narisuraksha/sms` for direct background SMS
/// sending. The existing [openSmsComposer] method is preserved as a fallback.
class SmsService {
  const SmsService();

  static const _channel = MethodChannel('com.narisuraksha/sms');

  // ── Message building ────────────────────────────────────────────────────────

  /// Constructs a professional emergency alert message tailored by priority escalation level.
  ///
  /// [userName]  — The authenticated user's display name (or 'A Nari Suraksha user').
  /// [mapsUrl]   — Google Maps URL with real GPS coordinates.
  /// [timestamp] — The exact time of the SOS alert.
  /// [priority]  — The escalation tier (High, Medium, Low).
  String buildEmergencyMessage({
    required String userName,
    required String mapsUrl,
    required DateTime timestamp,
    ContactPriority priority = ContactPriority.high,
  }) {
    final title = switch (priority) {
      ContactPriority.high => '🚨 URGENT: Nari Suraksha SOS – High Priority Alert',
      ContactPriority.medium =>
        '🚨 URGENT: Nari Suraksha SOS – Medium Priority Escalation',
      ContactPriority.low =>
        '🚨 URGENT: Nari Suraksha SOS – Final Contact Escalation',
    };
    final timeStr = _formatTimestamp(timestamp);
    return '''$title

$userName may be in danger and has triggered an SOS alert.

📍 Current Location:
$mapsUrl

⏰ Time: $timeStr

Please contact them immediately or call emergency services (Police: 112, Ambulance: 108) if required.

– Sent via Nari Suraksha Safety App''';
  }

  // –– Quick contact alert message ──────────────────────────────────────────

  /// Default emergency message sent when manually messaging an emergency contact.
  static const String defaultQuickAlertMessage =
      '🚨 Nari Suraksha Alert:\nI may need help. Please contact me immediately. This is an emergency.';

  /// Constructs the predefined emergency message for an individual contact alert.
  ///
  /// Can be overridden with [customMessage] if configured.
  String buildQuickAlertMessage({String? customMessage}) {
    return customMessage ?? defaultQuickAlertMessage;
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

  // ── Native SMS (direct send via Android SmsManager) ─────────────────────────

  /// Checks if SEND_SMS permission is currently granted.
  ///
  /// Returns `{granted: bool, permanentlyDenied: bool}`.
  Future<Map<String, bool>> checkSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<Map>('checkSmsPermission');
      return {
        'granted': result?['granted'] as bool? ?? false,
        'permanentlyDenied': result?['permanentlyDenied'] as bool? ?? false,
      };
    } on MissingPluginException {
      debugPrint('[SmsService] checkSmsPermission: MethodChannel not available (not on Android?)');
      return {'granted': false, 'permanentlyDenied': false};
    } catch (e) {
      debugPrint('[SmsService] checkSmsPermission error: $e');
      return {'granted': false, 'permanentlyDenied': false};
    }
  }

  /// Requests SEND_SMS permission from the user.
  ///
  /// Returns `true` if permission was granted.
  Future<bool> requestSmsPermission() async {
    try {
      final result = await _channel.invokeMethod<Map>('requestSmsPermission');
      return result?['granted'] as bool? ?? false;
    } on MissingPluginException {
      debugPrint('[SmsService] requestSmsPermission: MethodChannel not available');
      return false;
    } catch (e) {
      debugPrint('[SmsService] requestSmsPermission error: $e');
      return false;
    }
  }

  /// Checks if the device has SMS/telephony capability.
  Future<bool> hasSmsCapability() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsCapability');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('[SmsService] hasSmsCapability error: $e');
      return false;
    }
  }

  /// Sends an SMS directly via native Android SmsManager (no composer).
  ///
  /// Returns a [SmsSendResult] with success/failure status.
  /// If the native channel is unavailable, returns [SmsResult.failed].
  Future<SmsSendResult> sendDirectSms({
    required String phone,
    required String message,
    String contactName = '',
  }) async {
    final normalized = normalizePhone(phone);
    if (!isValidPhone(phone)) {
      debugPrint('[SmsService] sendDirectSms: invalid phone "$phone"');
      return SmsSendResult(
        phone: normalized,
        contactName: contactName,
        result: SmsResult.skipped,
        error: 'Invalid phone number',
      );
    }

    try {
      // Check and request runtime permission if not yet granted
      final perm = await checkSmsPermission();
      if (!perm['granted']!) {
        debugPrint('[SmsService] SEND_SMS permission not yet granted. Requesting...');
        final granted = await requestSmsPermission();
        if (!granted) {
          debugPrint('[SmsService] SEND_SMS permission was denied by user.');
          return SmsSendResult(
            phone: normalized,
            contactName: contactName,
            result: SmsResult.failed,
            error: 'SEND_SMS permission not granted',
          );
        }
      }

      final result = await _channel.invokeMethod<Map>('sendSms', {
        'phone': normalized,
        'message': message,
      });

      final success = result?['success'] as bool? ?? false;
      final error = result?['error'] as String?;

      debugPrint('[SmsService] sendDirectSms to $normalized ($contactName): success=$success, error=$error');

      return SmsSendResult(
        phone: normalized,
        contactName: contactName,
        result: success ? SmsResult.sent : SmsResult.failed,
        error: error,
      );
    } on MissingPluginException {
      debugPrint('[SmsService] sendDirectSms: MethodChannel not available');
      return SmsSendResult(
        phone: normalized,
        contactName: contactName,
        result: SmsResult.failed,
        error: 'SMS not available on this platform',
      );
    } catch (e) {
      debugPrint('[SmsService] sendDirectSms error: $e');
      return SmsSendResult(
        phone: normalized,
        contactName: contactName,
        result: SmsResult.failed,
        error: 'SMS send error: $e',
      );
    }
  }

  // ── SMS composer (fallback) ─────────────────────────────────────────────────

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
