import 'package:supabase_flutter/supabase_flutter.dart';

class AuditService {
  final SupabaseClient _supabase;

  AuditService(this._supabase);

  Future<void> _insertLog({
    required String categoria,
    required String nivel,
    required String mensaje,
    String? usuarioId,
    String? email,
    String? resultado,
    String origenIp = 'client_app',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('logs_sistema').insert({
        'categoria': categoria,
        'nivel': nivel,
        'mensaje': mensaje,
        'usuario_id': usuarioId,
        'email': email,
        'resultado': resultado,
        'origen_ip': origenIp,
        'metadata': metadata,
        'fecha_hora': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> logSystemError({
    required String mensaje,
    Map<String, dynamic>? metadata,
  }) async {
    await _insertLog(
      categoria: 'SISTEMA',
      nivel: 'ERROR',
      mensaje: mensaje,
      metadata: metadata,
    );
  }

  Future<void> logHealthCheck({
    required bool exitoso,
    required String mensaje,
    Map<String, dynamic>? metadata,
  }) async {
    await _insertLog(
      categoria: 'HEALTH_CHECK',
      nivel: exitoso ? 'INFO' : 'ERROR',
      mensaje: mensaje,
      metadata: metadata,
    );
  }

  Future<void> logAuthAttempt({
    required String email,
    required bool exitoso,
    String? usuarioId,
    String? detalleError,
  }) async {
    await _insertLog(
      categoria: 'AUTENTICACION',
      nivel: exitoso ? 'INFO' : 'WARNING',
      email: email,
      usuarioId: usuarioId,
      resultado: exitoso ? 'EXITOSO' : 'FALLIDO',
      mensaje: exitoso
          ? 'Inicio de sesión exitoso para $email'
          : 'Intento fallido de login para $email: ${detalleError ?? "Contraseña o datos incorrectos"}',
    );
  }
}
