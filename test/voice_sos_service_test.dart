import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/core/services/voice_sos_service.dart';

void main() {
  group('VoiceSosService.matchEmergencyPhrase', () {
    test('matches exact standard emergency phrases', () {
      expect(VoiceSosService.matchEmergencyPhrase('help'), equals('help'));
      expect(VoiceSosService.matchEmergencyPhrase('emergency'), equals('emergency'));
      expect(VoiceSosService.matchEmergencyPhrase('alert'), equals('alert'));
      expect(VoiceSosService.matchEmergencyPhrase('save me'), equals('save me'));
      expect(VoiceSosService.matchEmergencyPhrase('danger'), equals('danger'));
      expect(VoiceSosService.matchEmergencyPhrase('sos'), equals('sos'));
      expect(VoiceSosService.matchEmergencyPhrase('nari suraksha help'), equals('nari suraksha help'));
    });

    test('matches case-insensitively', () {
      expect(VoiceSosService.matchEmergencyPhrase('HELP'), equals('help'));
      expect(VoiceSosService.matchEmergencyPhrase('Emergency'), equals('emergency'));
      expect(VoiceSosService.matchEmergencyPhrase('SAVE ME'), equals('save me'));
      expect(VoiceSosService.matchEmergencyPhrase('DANGER'), equals('danger'));
      expect(VoiceSosService.matchEmergencyPhrase('SoS'), equals('sos'));
      expect(VoiceSosService.matchEmergencyPhrase('NARI SURAKSHA HELP'), equals('nari suraksha help'));
    });

    test('matches with punctuation and extra whitespace', () {
      expect(VoiceSosService.matchEmergencyPhrase('Help!'), equals('help'));
      expect(VoiceSosService.matchEmergencyPhrase('Emergency...'), equals('emergency'));
      expect(VoiceSosService.matchEmergencyPhrase('Save me!'), equals('save me'));
      expect(VoiceSosService.matchEmergencyPhrase('Nari Suraksha, help!'), equals('nari suraksha help'));
      expect(VoiceSosService.matchEmergencyPhrase('   sos   '), equals('sos'));
    });

    test('matches emergency keywords within full sentences', () {
      expect(VoiceSosService.matchEmergencyPhrase('I need help right now'), equals('help'));
      expect(VoiceSosService.matchEmergencyPhrase('This is a real emergency'), equals('emergency'));
      expect(VoiceSosService.matchEmergencyPhrase('Please save me from this situation'), equals('save me'));
      expect(VoiceSosService.matchEmergencyPhrase('Send an alert to my contacts'), equals('alert'));
    });

    test('false positive protection: partial words DO NOT match', () {
      // "helper" contains "help", but should NOT trigger
      expect(VoiceSosService.matchEmergencyPhrase('helper'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('helpful'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('unhelpful'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('I am a helper'), isNull);

      // "alerted" contains "alert"
      expect(VoiceSosService.matchEmergencyPhrase('alerted'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('alerting'), isNull);

      // "endangered" contains "danger"
      expect(VoiceSosService.matchEmergencyPhrase('endangered'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('dangerous'), isNull);

      // Common non-emergency words
      expect(VoiceSosService.matchEmergencyPhrase('hello'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('good morning'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('how are you'), isNull);
      expect(VoiceSosService.matchEmergencyPhrase(''), isNull);
      expect(VoiceSosService.matchEmergencyPhrase('   '), isNull);
    });

    test('custom emergency phrases support', () {
      final customPhrases = ['code red', 'red alert', 'bachao'];
      expect(
        VoiceSosService.matchEmergencyPhrase('code red', phrases: customPhrases),
        equals('code red'),
      );
      expect(
        VoiceSosService.matchEmergencyPhrase('BACHAO!', phrases: customPhrases),
        equals('bachao'),
      );
      expect(
        VoiceSosService.matchEmergencyPhrase('help', phrases: customPhrases),
        isNull,
      );
    });

    test('text normalization strips punctuation and collapses whitespace', () {
      expect(VoiceSosService.normalizeText('  HELP,   ME!!!  '), equals('help me'));
      expect(VoiceSosService.normalizeText('Nari - Suraksha... Help?'), equals('nari suraksha help'));
    });
  });
}
