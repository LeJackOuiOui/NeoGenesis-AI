import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/auth/login_modal.dart';

class AppErrorException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkTimeout;

  const AppErrorException(
    this.message, {
    this.statusCode,
    this.isNetworkTimeout = false,
  });

  @override
  String toString() => message;
}

class AppErrorHandler {
  AppErrorHandler._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool _loginDialogVisible = false;

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      showGlobal(details.exception);
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      showGlobal(error);
      return true;
    };
  }

  static String messageFor(Object error) {
    final status = statusCodeFor(error);
    switch (status) {
      case 401:
        return 'Tu sesión expiró. Inicia sesión nuevamente para continuar.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'No encontramos lo que buscabas. Actualiza la pantalla e inténtalo otra vez.';
      case 500:
        return 'Ocurrió un problema en el servidor. Inténtalo nuevamente más tarde.';
    }

    if (error is AppErrorException) return error.message;
    if (_isNetworkTimeout(error)) {
      return 'La conexión está tardando más de lo esperado. Comprueba tu conexión e inténtalo de nuevo.';
    }
    final errorType = error.runtimeType.toString();
    if (error is FunctionsFetchException ||
        errorType.contains('socketexception') ||
        errorType.contains('clientexception')) {
      return 'No pudimos conectar con el servicio. Comprueba tu conexión e inténtalo de nuevo.';
    }
    if (error is PostgrestException && error.code == '42501') {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (error is AuthException) {
      return 'No se pudo completar la autenticación. Revisa tus datos e inténtalo de nuevo.';
    }
    return 'Ocurrió un error inesperado. Inténtalo nuevamente. Si el problema continúa, contacta con soporte.';
  }

  static int? statusCodeFor(Object error) {
    if (error is AppErrorException) return error.statusCode;
    if (error is FunctionException && error.status > 0) return error.status;
    if (error is AuthException) return int.tryParse(error.statusCode ?? '');
    if (error is StorageException) {
      return int.tryParse(error.statusCode ?? '');
    }
    if (error is PostgrestException) {
      if (error.code == '42501') return 403;
      if (error.code == 'PGRST301') return 401;
      if (error.code == 'PGRST302') return 403;
      if (error.code == 'PGRST116' || error.code == 'PGRST205') return 404;
      if (error.code == 'PGRST000' ||
          error.code == 'PGRST001' ||
          error.code == 'PGRST002' ||
          error.code == 'PGRST003') {
        return 500;
      }
    }
    return null;
  }

  static bool _isNetworkTimeout(Object error) =>
      error is TimeoutException ||
      (error is AppErrorException && error.isNetworkTimeout) ||
      (error is FunctionsFetchException &&
          error.details.toString().toLowerCase().contains('timeout')) ||
      error.runtimeType.toString().toLowerCase().contains('timeout') ||
      error.runtimeType.toString().toLowerCase().contains(
        'retryablefetchexception',
      );

  static void show(
    BuildContext context,
    Object error, {
    Future<void> Function()? onRetry,
  }) {
    final status = statusCodeFor(error);
    if (status == 401) {
      _redirectToLogin();
    }
    _show(ScaffoldMessenger.of(context), error, onRetry: onRetry);
  }

  static void showGlobal(Object error) {
    if (statusCodeFor(error) == 401) _redirectToLogin();
    final messenger = messengerKey.currentState;
    if (messenger != null) _show(messenger, error);
  }

  static void _show(
    ScaffoldMessengerState messenger,
    Object error, {
    Future<void> Function()? onRetry,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(messageFor(error)),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
          action: _isNetworkTimeout(error) && onRetry != null
              ? SnackBarAction(
                  label: 'Reintentar',
                  textColor: Colors.white,
                  onPressed: () => unawaited(_retry(onRetry)),
                )
              : null,
        ),
      );
  }

  static Future<void> _retry(Future<void> Function() onRetry) async {
    try {
      await onRetry();
    } catch (error) {
      showGlobal(error);
    }
  }

  static void _redirectToLogin() {
    final client = Supabase.instance.client;
    if (client.auth.currentSession == null || _loginDialogVisible) return;
    _loginDialogVisible = true;
    unawaited(_openLoginDialog(client));
  }

  static Future<void> _openLoginDialog(SupabaseClient client) async {
    try {
      await client.auth.signOut();
    } on AuthException {
      // The local session is already unusable; continue to the login screen.
    }

    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      _loginDialogVisible = false;
      return;
    }
    navigator.popUntil((route) => route.isFirst);
    await showDialog<void>(
      context: navigator.context,
      builder: (_) => const LoginModal(),
    );
    _loginDialogVisible = false;
  }
}
