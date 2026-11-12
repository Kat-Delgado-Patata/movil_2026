import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:proyecto_final_asistencia/main.dart';

void main() {
  testWidgets('LoginScreen muestra el selector de rol y valida el correo institucional',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Estudiante'), findsOneWidget);
    expect(find.text('Docente'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'alumno@gmail.com');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.textContaining('@udla.edu.co'), findsWidgets);
  });
}
