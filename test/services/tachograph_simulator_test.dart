import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/models/tachograph_data.dart';
import 'package:takograpp_d1/services/tachograph_simulator.dart';

void main() {
  test('continuous driving and daily driving accumulate while driving', () {
    fakeAsync((async) {
      final sim = TachographSimulator();
      sim.startDriving();
      async.elapse(const Duration(minutes: 10));

      expect(sim.current.continuousDriving, const Duration(minutes: 10));
      expect(sim.current.dailyDriving, const Duration(minutes: 10));
      expect(sim.current.weeklyDriving.inMinutes, greaterThanOrEqualTo(10));

      sim.dispose();
    });
  });

  test(
    'a break shorter than 45 minutes does NOT reset continuousDriving '
    '(regression test for the Md.7 minimum-break bug)',
    () {
      fakeAsync((async) {
        final sim = TachographSimulator();
        sim.startDriving();
        async.elapse(const Duration(hours: 1));
        expect(sim.current.continuousDriving, const Duration(hours: 1));

        sim.setRest();
        async.elapse(const Duration(minutes: 10));

        sim.startDriving();
        async.elapse(const Duration(seconds: 1));

        // 10 dk mola AB 561/2006 Md.7'nin gerektirdiği 45 dk eşiğinin altında
        // kaldığı için sürekli sürüş sayacı sıfırlanmamalı, kaldığı yerden
        // devam etmeli.
        expect(
          sim.current.continuousDriving,
          greaterThan(const Duration(hours: 1)),
        );

        sim.dispose();
      });
    },
  );

  test(
    'a break of 45 minutes or more resets continuousDriving to zero',
    () {
      fakeAsync((async) {
        final sim = TachographSimulator();
        sim.startDriving();
        async.elapse(const Duration(hours: 1));
        expect(sim.current.continuousDriving, const Duration(hours: 1));

        sim.setRest();
        async.elapse(const Duration(minutes: 45));

        expect(sim.current.continuousDriving, Duration.zero);

        sim.dispose();
      });
    },
  );

  test(
    'an interrupted break does not carry over toward the 45-minute threshold',
    () {
      fakeAsync((async) {
        final sim = TachographSimulator();
        sim.startDriving();
        async.elapse(const Duration(hours: 1));

        sim.setRest();
        async.elapse(const Duration(minutes: 30));
        sim.startDriving();
        async.elapse(const Duration(seconds: 1));
        sim.setRest();
        async.elapse(const Duration(minutes: 30));

        // İki ayrı 30 dk'lık mola, aralarında sürüşle bölündüğü için 45 dk'lık
        // kesintisiz mola şartını sağlamaz — sürekli sürüş sayacı hâlâ sıfırlanmamalı.
        expect(
          sim.current.continuousDriving,
          greaterThan(const Duration(hours: 1)),
        );

        sim.dispose();
      });
    },
  );

  test(
    'startDriving() targets a speed below the 90 km/h limit, so no '
    'violations are recorded during normal simulated driving',
    () {
      fakeAsync((async) {
        final sim = TachographSimulator();
        sim.startDriving();
        async.elapse(const Duration(minutes: 5));

        expect(sim.current.speedKmh, lessThan(90.0));
        expect(sim.current.speedViolations24h, 0);

        sim.dispose();
      });
    },
  );

  test('remainingDriving is maxContinuousDriving minus continuousDriving, clamped at zero', () {
    fakeAsync((async) {
      final sim = TachographSimulator();
      sim.startDriving();
      async.elapse(const Duration(hours: 4, minutes: 30));

      expect(sim.current.remainingDriving, Duration.zero);
      expect(
        sim.current.continuousDriving,
        greaterThanOrEqualTo(const Duration(hours: 4, minutes: 30)),
      );

      sim.dispose();
    });
  });

  test('activity setters map to the expected DriverActivity values', () {
    fakeAsync((async) {
      final sim = TachographSimulator();

      sim.startDriving();
      async.elapse(const Duration(seconds: 1));
      expect(sim.current.activity, DriverActivity.driving);

      sim.takeBreak();
      async.elapse(const Duration(seconds: 1));
      expect(sim.current.activity, DriverActivity.available);

      sim.setRest();
      async.elapse(const Duration(seconds: 1));
      expect(sim.current.activity, DriverActivity.rest);

      sim.setWork();
      async.elapse(const Duration(seconds: 1));
      expect(sim.current.activity, DriverActivity.otherWork);

      sim.setAvailable();
      async.elapse(const Duration(seconds: 1));
      expect(sim.current.activity, DriverActivity.available);

      sim.dispose();
    });
  });
}
