import 'ble_exception.dart';

class BlePermissionException extends BleException {
  const BlePermissionException({required super.message, super.cause})
      : super(layer: 'permission');
}
