import '../models/ble_device_result.dart';

abstract class BleScannerRepository {
  Stream<List<BleDeviceResult>> get scanResults;
  Future<void> startScan({Duration timeout});
  Future<void> stopScan();
  Future<bool> isBluetoothOn();
  void dispose();
}
