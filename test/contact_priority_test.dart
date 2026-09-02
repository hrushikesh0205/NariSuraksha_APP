import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/models/contact_model.dart';

void main() {
  group('ContactPriority Enum Tests', () {
    test('ContactPriority.fromString handles valid strings', () {
      expect(ContactPriority.fromString('high'), ContactPriority.high);
      expect(ContactPriority.fromString('HIGH'), ContactPriority.high);
      expect(ContactPriority.fromString('medium'), ContactPriority.medium);
      expect(ContactPriority.fromString('MEDIUM'), ContactPriority.medium);
      expect(ContactPriority.fromString('low'), ContactPriority.low);
      expect(ContactPriority.fromString('LOW'), ContactPriority.low);
    });

    test('ContactPriority.fromString defaults safely to high for null or invalid values', () {
      expect(ContactPriority.fromString(null), ContactPriority.high);
      expect(ContactPriority.fromString(''), ContactPriority.high);
      expect(ContactPriority.fromString('urgent'), ContactPriority.high);
      expect(ContactPriority.fromString('unknown'), ContactPriority.high);
    });

    test('ContactPriority properties have correct labels and timing', () {
      expect(ContactPriority.high.value, 'high');
      expect(ContactPriority.medium.value, 'medium');
      expect(ContactPriority.low.value, 'low');

      expect(ContactPriority.high.escalationMinutes, 0);
      expect(ContactPriority.medium.escalationMinutes, 2);
      expect(ContactPriority.low.escalationMinutes, 5);

      expect(ContactPriority.high.timingLabel, 'Immediate Alert');
      expect(ContactPriority.medium.timingLabel, 'Alert after 2 min');
      expect(ContactPriority.low.timingLabel, 'Alert after 5 min');
    });
  });

  group('EmergencyContact Priority Serialization Tests', () {
    test('Default constructor sets priority to high', () {
      const contact = EmergencyContact(
        userId: 'user_123',
        name: 'Mom',
        phone: '+919876543210',
        relation: 'Mother',
      );

      expect(contact.priority, ContactPriority.high);
    });

    test('Explicit priority is preserved', () {
      const contact = EmergencyContact(
        userId: 'user_123',
        name: 'Neighbor',
        phone: '+919876543211',
        relation: 'Neighbor',
        priority: ContactPriority.low,
      );

      expect(contact.priority, ContactPriority.low);
    });

    test('toMap() and toCreateMap() include priority field', () {
      const contact = EmergencyContact(
        userId: 'user_123',
        name: 'Sister',
        phone: '+919876543212',
        relation: 'Sister',
        priority: ContactPriority.medium,
      );

      final updateMap = contact.toMap();
      final createMap = contact.toCreateMap();

      expect(updateMap['priority'], 'medium');
      expect(createMap['priority'], 'medium');
      expect(updateMap['name'], 'Sister');
      expect(createMap['phone'], '+919876543212');
    });

    test('copyWith updates priority correctly', () {
      const contact = EmergencyContact(
        userId: 'user_123',
        name: 'Friend',
        phone: '+919876543213',
        priority: ContactPriority.high,
      );

      final updated = contact.copyWith(priority: ContactPriority.low);

      expect(updated.priority, ContactPriority.low);
      expect(updated.name, 'Friend');
      expect(updated.phone, '+919876543213');
    });
  });

  group('Contact Filtering by Priority Tests', () {
    final contacts = [
      const EmergencyContact(
        id: '1',
        userId: 'u1',
        name: 'Mom',
        phone: '+919876543210',
        priority: ContactPriority.high,
      ),
      const EmergencyContact(
        id: '2',
        userId: 'u1',
        name: 'Dad',
        phone: '+919876543211',
        priority: ContactPriority.high,
      ),
      const EmergencyContact(
        id: '3',
        userId: 'u1',
        name: 'Sister',
        phone: '+919876543212',
        priority: ContactPriority.medium,
      ),
      const EmergencyContact(
        id: '4',
        userId: 'u1',
        name: 'Colleague',
        phone: '+919876543213',
        priority: ContactPriority.low,
      ),
    ];

    test('Filters contacts by High, Medium, Low correctly', () {
      final high = contacts.where((c) => c.priority == ContactPriority.high).toList();
      final medium = contacts.where((c) => c.priority == ContactPriority.medium).toList();
      final low = contacts.where((c) => c.priority == ContactPriority.low).toList();

      expect(high.length, 2);
      expect(high.map((c) => c.name), containsAll(['Mom', 'Dad']));

      expect(medium.length, 1);
      expect(medium.first.name, 'Sister');

      expect(low.length, 1);
      expect(low.first.name, 'Colleague');
    });

    test('Handles empty priority tiers gracefully', () {
      final onlyHighContacts = [
        const EmergencyContact(
          id: '1',
          userId: 'u1',
          name: 'Mom',
          phone: '+919876543210',
          priority: ContactPriority.high,
        ),
      ];

      final medium = onlyHighContacts.where((c) => c.priority == ContactPriority.medium).toList();
      final low = onlyHighContacts.where((c) => c.priority == ContactPriority.low).toList();

      expect(medium, isEmpty);
      expect(low, isEmpty);
    });
  });
}
