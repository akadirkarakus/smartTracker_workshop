import '../models/ble_gatt_service.dart';
import '../models/log_entry.dart';

enum BleConnectionState { disconnected, connecting, connected, disconnecting }

abstract class BleConnectionRepository {
  Stream<BleConnectionState> get connectionState;
  Stream<LogEntry> get logs;

  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<List<BleGattService>> discoverServices();
  Future<List<int>> readCharacteristic(String charUuid);
  Future<void> writeCharacteristic(String charUuid, List<int> data);
  Future<void> setNotify(String charUuid, {required bool enable});
  Stream<List<int>> notifyStream(String charUuid);
  Future<void> dispose();
}
