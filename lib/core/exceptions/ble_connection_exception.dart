import 'ble_exception.dart';

class BleConnectionException extends BleException {
  const BleConnectionException({required super.message, super.cause})
      : super(layer: 'connection');
}
