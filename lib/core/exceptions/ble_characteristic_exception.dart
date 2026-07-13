import 'ble_exception.dart';

class BleCharacteristicException extends BleException {
  const BleCharacteristicException({required super.message, super.cause})
      : super(layer: 'characteristic');
}
