import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/core/utils/validators.dart';

void main() {
  group('FormValidators', () {
    test('valida correos comunes y detecta formato incorrecto', () {
      expect(FormValidators.email('ana.lopez@example.com'), isNull);
      expect(FormValidators.email('ana+rrhh@empresa.com'), isNull);
      expect(FormValidators.email('ana.example.com'), isNotNull);
      expect(FormValidators.email('ana@@example.com'), isNotNull);
      expect(FormValidators.email('ana..lopez@example.com'), isNotNull);
      expect(FormValidators.email(''), isNotNull);
      expect(FormValidators.email('', required: false), isNull);
    });

    test('valida nombre y teléfono', () {
      expect(FormValidators.personName('Ana María López'), isNull);
      expect(FormValidators.personName("Jean-Luc O'Neil"), isNull);
      expect(FormValidators.personName('Ana 4'), isNotNull);
      expect(FormValidators.personName('A'), isNotNull);
      expect(FormValidators.phone('+51 (999) 123-456'), isNull);
      expect(FormValidators.phone('123ABC'), isNotNull);
      expect(FormValidators.phone('12345'), isNotNull);
      expect(FormValidators.phone('', required: false), isNull);
    });

    test('valida números, contraseñas y confirmación', () {
      expect(FormValidators.positiveNumber('1,25', allowZero: true), isNull);
      expect(FormValidators.positiveNumber('abc', allowZero: true), isNotNull);
      expect(FormValidators.positiveNumber('-1', allowZero: true), isNotNull);
      expect(FormValidators.password('Password123'), isNull);
      expect(FormValidators.password('12345678'), isNotNull);
      expect(FormValidators.password('Pass1'), isNotNull);
      expect(
        FormValidators.confirmedPassword('Password123', 'Password123'),
        isNull,
      );
      expect(
        FormValidators.confirmedPassword('different', 'Password123'),
        isNotNull,
      );
    });
  });
}
