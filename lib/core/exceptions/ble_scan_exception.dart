import 'ble_exception.dart';

class BleScanException extends BleException {
  const BleScanException({required super.message, super.cause})
      : super(layer: 'scan');
}
