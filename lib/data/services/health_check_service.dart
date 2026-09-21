import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_service.dart';

class HealthService {
  final SupabaseClient _supabase;
  final AuditService _auditService;
  final DateTime _startTime = DateTime.now();

  HealthService(this._supabase) : _auditService = AuditService(_supabase);

  Future<Map<String, dynamic>> checkHealth() async {
    String dbStatus = 'disconnected';
    int? latencyMs;

    try {
      final pingStart = DateTime.now();
      await _supabase.from('profiles').select('id').limit(1).maybeSingle();
      latencyMs = DateTime.now().difference(pingStart).inMilliseconds;
      dbStatus = 'connected';

      await _auditService.logHealthCheck(
        exitoso: true,
        mensaje: 'Health Check OK (${latencyMs}ms)',
        metadata: {'latency_ms': latencyMs},
      );
    } catch (e) {
      dbStatus = 'error: ${e.toString()}';

      await _auditService.logHealthCheck(
        exitoso: false,
        mensaje: 'Error de conexión en Health Check: $e',
      );
    }

    final isHealthy = dbStatus == 'connected';
    final uptimeSeconds = DateTime.now().difference(_startTime).inSeconds;

    return {
      'status': isHealthy ? 'OK' : 'ERROR',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'uptime': '${uptimeSeconds}s',
      'database': {
        'provider': 'Supabase (PostgreSQL)',
        'status': dbStatus,
        'latency': latencyMs != null ? '${latencyMs}ms' : null,
      },
    };
  }
}
