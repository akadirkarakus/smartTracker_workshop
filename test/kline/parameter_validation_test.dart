import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/kline/parameter_validation.dart';

void main() {
  group('ParameterValidator.validateNumberInRange', () {
    test('accepts a value within range', () {
      expect(
        ParameterValidator.validateNumberInRange('30', label: 'Test', min: 0, max: 60),
        30,
      );
    });

    test('accepts the exact min/max boundaries', () {
      expect(
        ParameterValidator.validateNumberInRange('0', label: 'Test', min: 0, max: 60),
        0,
      );
      expect(
        ParameterValidator.validateNumberInRange('60', label: 'Test', min: 0, max: 60),
        60,
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        ParameterValidator.validateNumberInRange(' 42 ', label: 'Test', min: 0, max: 100),
        42,
      );
    });

    test('rejects empty input', () {
      expect(
        () => ParameterValidator.validateNumberInRange('', label: 'Test', min: 0, max: 60),
        throwsA(isA<ParamValidationException>()),
      );
    });

    test('rejects a decimal point', () {
      expect(
        () => ParameterValidator.validateNumberInRange('12.5', label: 'Test', min: 0, max: 60),
        throwsA(isA<ParamValidationException>()),
      );
    });

    test('rejects non-numeric input', () {
      expect(
        () => ParameterValidator.validateNumberInRange('abc', label: 'Test', min: 0, max: 60),
        throwsA(isA<ParamValidationException>()),
      );
    });

    test('rejects a value below the minimum', () {
      expect(
        () => ParameterValidator.validateNumberInRange('-1', label: 'Test', min: 0, max: 60),
        throwsA(isA<ParamValidationException>()),
      );
    });

    test('rejects a value above the maximum', () {
      expect(
        () => ParameterValidator.validateNumberInRange('70000', label: 'Test', min: 1, max: 60000),
        throwsA(isA<ParamValidationException>()),
      );
    });

    test('error message includes the given label and range', () {
      try {
        ParameterValidator.validateNumberInRange('999', label: 'Hız Göstergesi Faktörü', min: 1, max: 60);
        fail('should have thrown');
      } on ParamValidationException catch (e) {
        expect(e.message, contains('Hız Göstergesi Faktörü'));
        expect(e.message, contains('1–60'));
      }
    });
  });
}
