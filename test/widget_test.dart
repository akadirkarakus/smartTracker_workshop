import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/main.dart';
import 'package:takograpp_d1/screens/calibration_screen.dart';

void main() {
  testWidgets('App launches directly into Servis dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const TachographApp());
    await tester.pump();

    expect(find.byType(CalibrationScreen), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });
}
