// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neogenesis_ai/data/services/api_service.dart';
import 'package:neogenesis_ai/main.dart';
import 'package:neogenesis_ai/screens/home/home_screen.dart';

void main() {
  testWidgets('La aplicación renderiza la pantalla principal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MainApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  test('El payload de empleado evita columnas no existentes en esquemas antiguos', () {
    final payload = ApiService.buildEmployeeUpdatePayload(
      nombre: 'Ana López',
      cargo: 'Analista',
      salarioBase: 2200,
      tipoContrato: 'Tiempo Completo',
      fechaIngreso: DateTime(2024, 4, 15),
      includeSalaryFields: false,
    );

    expect(payload['nombre'], 'Ana López');
    expect(payload['cargo'], 'Analista');
    expect(payload['tipo_contrato'], 'Tiempo Completo');
    expect(payload.containsKey('salario_base'), isFalse);
  });

  test('La validación de correo acepta solo Gmail y rechaza otros dominios', () {
    expect(ApiService.isValidGmailEmail('usuario@gmail.com'), isTrue);
    expect(ApiService.isValidGmailEmail('usuario@googlemail.com'), isTrue);
    expect(ApiService.isValidGmailEmail('usuario@outlook.com'), isFalse);
    expect(ApiService.isValidGmailEmail('usuario@empresa.com'), isFalse);
    expect(ApiService.isValidGmailEmail(''), isFalse);
  });
}
