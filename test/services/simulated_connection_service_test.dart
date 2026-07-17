// Regression test for the "no data in simulation mode" bug: KLineService
// writes each frame one byte at a time (ISO 14230 P4min pacing), and
// SimulatedConnectionService must reassemble those bytes back into full
// frames before responding — otherwise every RDBI/StartCommunication call
// times out and readAllCalibrationData() returns an all-null snapshot.
import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/bluetooth/services/simulated_connection_service.dart';
import 'package:takograpp_d1/kline/kline_service.dart';

void main() {
  test('readAllCalibrationData() returns populated fields over the simulated transport', () async {
    final transport = SimulatedConnectionService();
    await transport.connect('SIM-DEVICE');
    final service = KLineService(transport);

    final snapshot = await service.readAllCalibrationData();

    expect(snapshot.vin, isNotNull);
    expect(snapshot.vrn, isNotNull);
    expect(snapshot.hwNumber, isNotNull);
    expect(snapshot.kConstant, isNotNull);
    expect(snapshot.wConstant, isNotNull);
    expect(snapshot.odometer, isNotNull);

    service.dispose();
    await transport.dispose();
  });

  test('readDtcCodes() returns the mock DTC list over the simulated transport', () async {
    final transport = SimulatedConnectionService();
    await transport.connect('SIM-DEVICE');
    final service = KLineService(transport);

    final dtcs = await service.readDtcCodes();
    expect(dtcs, isNotEmpty);

    service.dispose();
    await transport.dispose();
  });
}
