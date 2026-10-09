// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:marcador_asistencia/main.dart';

void main() {
  testWidgets('Carga inicial de la app', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Ingreso al Sistema'), findsOneWidget);
  });
}