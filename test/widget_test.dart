import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/main.dart';

void main() {
  testWidgets('MonitorScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TachographApp());
    await tester.pump();

    expect(find.text('Takograf İzleme'), findsOneWidget);
    expect(find.text('SİMÜLASYON'), findsOneWidget);
  });
}
