import 'package:flutter_test/flutter_test.dart';
import 'package:takograpp_d1/main.dart';

void main() {
  testWidgets('Şoför role navigates to MonitorScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const TachographApp());
    await tester.pump();

    expect(find.text('Rol Seçin'), findsOneWidget);

    await tester.tap(find.text('Şoför'));
    // MonitorScreen sürekli tikleyen bir Timer.periodic simülatörü kullandığı
    // için pumpAndSettle hiç durmaz; sayfa geçiş animasyonunu sınırlı sayıda
    // pump ile manuel olarak bekle.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Takograf İzleme'), findsOneWidget);
    expect(find.text('SİMÜLASYON'), findsOneWidget);
  });
}
