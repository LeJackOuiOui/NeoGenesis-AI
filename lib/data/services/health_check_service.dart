import 'package:supabase_flutter/supabase_flutter.dart';

class HealthService {
  final SupabaseClient _supabase;
  final DateTime _startTime = DateTime.now();

  HealthService(this._supabase);

  Future<Map<String, dynamic>> checkHealth() async {
    String dbStatus = 'disconnected';
    int? latencyMs;

    try {
      final pingStart = DateTime.now();

      await _supabase.from('profiles').select('id').limit(1).maybeSingle();

      final pingEnd = DateTime.now();
      latencyMs = pingEnd.difference(pingStart).inMilliseconds;
      dbStatus = 'connected';
    } catch (e) {
      dbStatus = 'error: ${e.toString()}';
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
