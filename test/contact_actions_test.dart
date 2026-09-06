import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/models/contact_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smsService = SmsService();
  const channel = MethodChannel('com.narisuraksha/sms');

  group('CALL Action Tests', () {
    test('Correct contact number is normalized for Indian formats and local formatting', () {
      expect(smsService.normalizePhone('+91 98765 43210'), '+919876543210');
      expect(smsService.normalizePhone('+91-98765-43210'), '+919876543210');
      expect(smsService.normalizePhone('98765 43210'), '9876543210');
      expect(smsService.normalizePhone('09876543210'), '09876543210');
      expect(smsService.normalizePhone('+91 9876543210'), '+919876543210');
    });

    test('Correct tel URI is constructed from normalized contact phone', () {
      const contact = EmergencyContact(
        userId: 'test_u1',
        name: 'Priya Sharma',
        phone: '+91 98765 43210',
        relation: 'Sister',
      );

      final normalized = smsService.normalizePhone(contact.phone);
      final uri = Uri(scheme: 'tel', path: normalized);

      expect(uri.scheme, 'tel');
      expect(uri.path, '+919876543210');
      expect(uri.toString(), 'tel:+919876543210');
    });

    test('Invalid contact phone numbers are rejected', () {
      expect(smsService.isValidPhone('123'), isFalse);
      expect(smsService.isValidPhone('abcde'), isFalse);
      expect(smsService.isValidPhone('phone123'), isFalse);
      expect(smsService.isValidPhone('9999999999999999999'), isFalse); // > 15 digits
    });

    test('Missing contact phone numbers are rejected', () {
      expect(smsService.isValidPhone(''), isFalse);
      expect(smsService.isValidPhone('   '), isFalse);
    });
  });

  group('MESSAGE Action Tests', () {
    test('Predefined emergency message is generated correctly with exact text', () {
      final message = smsService.buildQuickAlertMessage();
      expect(
        message,
        '🚨 Nari Suraksha Alert:\nI may need help. Please contact me immediately. This is an emergency.',
      );
      expect(message, SmsService.defaultQuickAlertMessage);
    });

    test('Predefined emergency message is configurable in code/service', () {
      const custom = 'Custom Emergency Alert: Please help!';
      final message = smsService.buildQuickAlertMessage(customMessage: custom);
      expect(message, custom);
    });

    test('Direct SMS uses the correct contact number and predefined message', () async {
      String? sentPhone;
      String? sentMessage;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkSmsPermission') {
          return {'granted': true, 'permanentlyDenied': false};
        } else if (methodCall.method == 'sendSms') {
          final args = methodCall.arguments as Map;
          sentPhone = args['phone'] as String?;
          sentMessage = args['message'] as String?;
          return {'success': true, 'error': null};
        }
        return null;
      });

      const contact = EmergencyContact(
        userId: 'test_u1',
        name: 'Anita',
        phone: '+91 98765 12345',
        relation: 'Mother',
      );

      final msg = smsService.buildQuickAlertMessage();
      final result = await smsService.sendDirectSms(
        phone: contact.phone,
        message: msg,
        contactName: contact.name,
      );

      expect(result.result, SmsResult.sent);
      expect(result.phone, '+919876512345');
      expect(result.contactName, 'Anita');
      expect(sentPhone, '+919876512345');
      expect(sentMessage, SmsService.defaultQuickAlertMessage);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Direct SMS handles SMS permission granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkSmsPermission') {
          return {'granted': true, 'permanentlyDenied': false};
        } else if (methodCall.method == 'sendSms') {
          return {'success': true, 'error': null};
        }
        return null;
      });

      final result = await smsService.sendDirectSms(
        phone: '+919876543210',
        message: smsService.buildQuickAlertMessage(),
      );

      expect(result.result, SmsResult.sent);
      expect(result.error, isNull);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Direct SMS handles SMS permission request flow when granted', () async {
      var requestPermissionCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkSmsPermission') {
          return {'granted': false, 'permanentlyDenied': false};
        } else if (methodCall.method == 'requestSmsPermission') {
          requestPermissionCalled = true;
          return {'granted': true};
        } else if (methodCall.method == 'sendSms') {
          return {'success': true, 'error': null};
        }
        return null;
      });

      final result = await smsService.sendDirectSms(
        phone: '+919876543210',
        message: smsService.buildQuickAlertMessage(),
      );

      expect(requestPermissionCalled, isTrue);
      expect(result.result, SmsResult.sent);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Direct SMS handles SMS permission denied gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkSmsPermission') {
          return {'granted': false, 'permanentlyDenied': false};
        } else if (methodCall.method == 'requestSmsPermission') {
          return {'granted': false};
        }
        return null;
      });

      final result = await smsService.sendDirectSms(
        phone: '+919876543210',
        message: smsService.buildQuickAlertMessage(),
      );

      expect(result.result, SmsResult.failed);
      expect(result.error, contains('SEND_SMS permission not granted'));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Direct SMS handles native SMS failure gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkSmsPermission') {
          return {'granted': true, 'permanentlyDenied': false};
        } else if (methodCall.method == 'sendSms') {
          return {'success': false, 'error': 'No cellular signal'};
        }
        return null;
      });

      final result = await smsService.sendDirectSms(
        phone: '+919876543210',
        message: smsService.buildQuickAlertMessage(),
      );

      expect(result.result, SmsResult.failed);
      expect(result.error, 'No cellular signal');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Direct SMS skips invalid phone numbers with descriptive result', () async {
      final result = await smsService.sendDirectSms(
        phone: 'invalid',
        message: smsService.buildQuickAlertMessage(),
      );

      expect(result.result, SmsResult.skipped);
      expect(result.error, 'Invalid phone number');
    });
  });

  group('SOS Escalation Isolation Tests', () {
    test('SmsService retains separate buildEmergencyMessage for automated SOS escalation', () {
      final sosMsg = smsService.buildEmergencyMessage(
        userName: 'Aarti',
        mapsUrl: 'https://www.google.com/maps/search/?api=1&query=18.5204,73.8567',
        timestamp: DateTime(2026, 9, 7, 12, 30),
        priority: ContactPriority.high,
      );

      expect(sosMsg, contains('URGENT: Nari Suraksha SOS – High Priority Alert'));
      expect(sosMsg, contains('Aarti may be in danger'));
      expect(sosMsg, contains('https://www.google.com/maps/search/?api=1&query=18.5204,73.8567'));
      expect(sosMsg, contains('Police: 112'));

      final quickMsg = smsService.buildQuickAlertMessage();
      expect(quickMsg, contains('🚨 Nari Suraksha Alert:'));
      expect(quickMsg, isNot(contains('URGENT: Nari Suraksha SOS')));
      expect(quickMsg, isNot(contains('Police: 112')));
    });

    test('Medium and Low SOS priority escalation messages remain intact', () {
      final medMsg = smsService.buildEmergencyMessage(
        userName: 'Aarti',
        mapsUrl: 'https://www.google.com/maps/search/?api=1&query=18.5204,73.8567',
        timestamp: DateTime(2026, 9, 7, 12, 34),
        priority: ContactPriority.medium,
      );
      expect(medMsg, contains('Medium Priority Escalation'));

      final lowMsg = smsService.buildEmergencyMessage(
        userName: 'Aarti',
        mapsUrl: 'https://www.google.com/maps/search/?api=1&query=18.5204,73.8567',
        timestamp: DateTime(2026, 9, 7, 12, 38),
        priority: ContactPriority.low,
      );
      expect(lowMsg, contains('Final Contact Escalation'));
    });
  });
}
