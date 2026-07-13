import 'ble_exception.dart';

class BleAdapterException extends BleException {
  const BleAdapterException({required super.message, super.cause})
      : super(layer: 'adapter');
}
