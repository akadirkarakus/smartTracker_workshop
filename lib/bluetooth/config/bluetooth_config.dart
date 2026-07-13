import '../repositories/ble_connection_repository.dart';
import '../repositories/ble_scanner_repository.dart';
import '../services/ble_connection_service.dart';
import '../services/ble_scanner_service.dart';
import '../services/classic_connection_service.dart';
import '../services/classic_scanner_service.dart';
import '../services/simulated_connection_service.dart';

const _raw = String.fromEnvironment('BT_TRANSPORT', defaultValue: 'classic');

enum BtTransport { ble, classic, simulated }

final btTransport = _raw == 'classic' ? BtTransport.classic : BtTransport.ble;

BleScannerRepository createScannerService([BtTransport? transport]) {
  final t = transport ?? btTransport;
  return t == BtTransport.classic
      ? ClassicBluetoothScannerService()
      : FlutterBluePlusScannerService();
}

BleConnectionRepository createConnectionService([BtTransport? transport]) {
  final t = transport ?? btTransport;
  if (t == BtTransport.simulated) return SimulatedConnectionService();
  return t == BtTransport.classic
      ? ClassicBluetoothConnectionService()
      : FlutterBluePlusConnectionService();
}
