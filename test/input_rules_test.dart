import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/models/device_model.dart';
import 'package:healthsync/utils/dosage_strength.dart';
import 'package:healthsync/utils/phone_format.dart';
import 'package:healthsync/utils/validators.dart';

/// Input rules from the Oct 23 test round: BUG-016/017 (phone), BUG-020
/// (stock) and BUG-018/019 (dosage strength).
void main() {
  group('PhPhone', () {
    test('reads every form people type or paste', () {
      for (final input in [
        '9617840760',
        '961 784 0760',
        '09617840760',
        '639617840760',
        '+63 961 784 0760',
      ]) {
        expect(PhPhone.localDigits(input), '9617840760', reason: input);
      }
    });

    test('refuses what is not a Philippine mobile number', () {
      expect(PhPhone.localDigits('8617840760'), isNull); // not 9…
      expect(PhPhone.localDigits('961784076'), isNull); // 9 digits
      expect(PhPhone.localDigits('0' * 40), isNull); // the test account
      expect(PhPhone.localDigits(''), '');
    });

    test('stores +63 and the 10 digits, or nothing', () {
      expect(PhPhone.toStored('961 784 0760'), '+639617840760');
      expect(PhPhone.toStored(''), '');
    });

    test('a saved number fills the field, a bad one leaves it empty', () {
      expect(PhPhone.forField('+639617840760'), '961 784 0760');
      expect(PhPhone.forField('0' * 40), '');
      expect(PhPhone.isUnreadable('0' * 40), isTrue);
      expect(PhPhone.isUnreadable(''), isFalse);
    });

    test('display keeps an unreadable value as it is', () {
      expect(PhPhone.display('+639617840760'), '+63 961 784 0760');
      expect(PhPhone.display('12345'), '12345');
    });

    TextEditingValue type(String text) => PhPhoneInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('the field stops at 10 digits and spaces them', () {
      expect(type('96178407601234').text, '961 784 0760');
      expect(type('961a78').text, '961 78');
    });

    test('pasting a full number drops its prefix', () {
      expect(type('09617840760').text, '961 784 0760');
      expect(type('+63 961 784 0760').text, '961 784 0760');
    });

    test('validator: optional, but exact when filled', () {
      expect(Validators.phPhone(''), isNull);
      expect(Validators.phPhone('', isRequired: true), isNotNull);
      expect(Validators.phPhone('961 784 0760'), isNull);
      expect(Validators.phPhone('861 784 0760'), isNotNull);
    });
  });

  group('Validators.stock', () {
    test('accepts 0–999 on hand and 0–99 for the alert', () {
      expect(Validators.stock('30', '5'), isNull);
      expect(Validators.stock('999', '99'), isNull);
      expect(Validators.stock('0', '0'), isNull);
    });

    test('refuses too large or not a number', () {
      expect(Validators.stock('1000', '5'), isNotNull);
      expect(Validators.stock('30', '100'), isNotNull);
      expect(Validators.stock('5464878464640000000000', '1'), isNotNull);
      expect(Validators.stock('', '5'), isNotNull);
    });

    test('alert above the stock is refused only when adding', () {
      expect(Validators.stock('20', '50', alertWithinStock: true), isNotNull);
      // Edit: the count falls below the alert as doses are taken.
      expect(Validators.stock('2', '5'), isNull);
    });
  });

  group('Box serial', () {
    test('typed forms become HS-0001', () {
      for (final input in ['HS-0001', 'hs-0001', 'HS0001', ' hs 0001 ']) {
        expect(DeviceModel.normaliseSerial(input), 'HS-0001', reason: input);
      }
    });

    test('validator refuses the test-round serials', () {
      expect(Validators.deviceSerial('HS-0001'), isNull);
      expect(Validators.deviceSerial('hs0001'), isNull);
      expect(Validators.deviceSerial('ANYA100'), isNotNull);
      expect(Validators.deviceSerial('10000000000000'), isNotNull);
      expect(Validators.deviceSerial(''), isNotNull);
    });
  });

  group('DeviceModel.isOnline', () {
    DeviceModel box(String status, DateTime? lastSync) => DeviceModel(
          deviceId: 'HS-0001',
          deviceName: 'Box',
          serialNumber: 'HS-0001',
          status: status,
          lastSync: lastSync,
          createdAt: DateTime(2026),
        );

    test('needs a recent report, not just the stored status', () {
      final now = DateTime.now();
      expect(box('online', now).isOnline, isTrue);
      expect(box('online', now.subtract(const Duration(days: 4))).isOnline,
          isFalse);
      expect(box('online', null).isOnline, isFalse);
      expect(box('offline', now).isOnline, isFalse);
    });
  });

  group('DosageStrength', () {
    test('units follow the dosage form', () {
      expect(DosageStrength.unitsFor('Tablet').first, 'mg');
      expect(DosageStrength.unitsFor('Liquid').first, 'ml');
      expect(DosageStrength.unitsFor('Inhaler').first, 'puff');
    });

    test('reads saved values with or without a space', () {
      expect(DosageStrength.parse('500mg'), (amount: '500', unit: 'mg'));
      expect(DosageStrength.parse('2.5 ml'), (amount: '2.5', unit: 'ml'));
      expect(DosageStrength.parse('as directed'), isNull);
    });

    test('saves as one string', () {
      expect(DosageStrength.format('500', 'mg'), '500 mg');
    });

    test('amount: a positive number', () {
      expect(DosageStrength.validateAmount('500'), isNull);
      expect(DosageStrength.validateAmount(''), isNotNull);
      expect(DosageStrength.validateAmount('0'), isNotNull);
    });

    TextEditingValue type(String old, String text) =>
        DosageAmountInputFormatter().formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: text),
        );

    test('the amount stops at 6 characters and 2 decimals', () {
      expect(type('123456', '1234567').text, '123456');
      expect(type('2.55', '2.555').text, '2.55');
      expect(type('25', '25mg').text, '25');
    });
  });
}
