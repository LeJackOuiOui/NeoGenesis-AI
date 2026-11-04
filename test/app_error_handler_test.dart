import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/core/utils/app_error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppErrorHandler', () {
    test('traduce los códigos HTTP a mensajes entendibles', () {
      expect(
        AppErrorHandler.messageFor(const FunctionException(status: 401)),
        contains('sesión expiró'),
      );
      expect(
        AppErrorHandler.messageFor(const FunctionException(status: 403)),
        contains('No tienes permiso'),
      );
      expect(
        AppErrorHandler.messageFor(const FunctionException(status: 404)),
        contains('No encontramos'),
      );
      expect(
        AppErrorHandler.messageFor(const FunctionException(status: 500)),
        contains('servidor'),
      );
    });

    test('traduce errores de PostgREST y autenticación', () {
      expect(
        AppErrorHandler.messageFor(
          const PostgrestException(message: 'denied', code: '42501'),
        ),
        contains('No tienes permiso'),
      );
      expect(
        AppErrorHandler.messageFor(
          const AuthException('expired', statusCode: '401'),
        ),
        contains('sesión expiró'),
      );
      expect(
        AppErrorHandler.messageFor(
          const AppErrorException(
            'El servicio no está disponible.',
            statusCode: 404,
          ),
        ),
        contains('No encontramos'),
      );
      expect(
        AppErrorHandler.messageFor(
          const StorageException('technical detail', statusCode: '500'),
        ),
        contains('servidor'),
      );
    });

    test('identifica timeouts sin exponer el detalle técnico', () {
      expect(
        AppErrorHandler.messageFor(TimeoutException('Socket timed out')),
        contains('Comprueba tu conexión'),
      );
      expect(
        AppErrorHandler.messageFor(
          const FunctionsFetchException(details: 'Request timed out'),
        ),
        contains('Comprueba tu conexión'),
      );
      expect(
        AppErrorHandler.messageFor(TimeoutException('secret technical data')),
        isNot(contains('secret technical data')),
      );
    });

    testWidgets('ofrece reintentar ante un timeout de red', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AppErrorHandler.show(
                  context,
                  TimeoutException('network timed out'),
                  onRetry: () async {
                    retries++;
                  },
                );
              });
              return const Scaffold(body: Text('Inicio'));
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Reintentar'), findsOneWidget);
      final retryAction = tester.widget<SnackBarAction>(
        find.byType(SnackBarAction),
      );
      retryAction.onPressed();
      await tester.pump();
      expect(retries, 1);
    });
  });
}
