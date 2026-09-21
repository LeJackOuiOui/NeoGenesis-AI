import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/health_check_service.dart';

class ViewLogs extends StatefulWidget {
  const ViewLogs({super.key});

  @override
  State<ViewLogs> createState() => _ViewLogsState();
}

class _ViewLogsState extends State<ViewLogs> {
  final supabase = Supabase.instance.client;
  late final HealthService _healthService;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;

  // Consola de Health Check
  final List<String> _consoleLogs = [];
  bool _isCheckingHealth = false;

  @override
  void initState() {
    super.initState();
    _healthService = HealthService(supabase);
    _cargarLogs();
    _runHealthCheck();
  }

  Future<void> _cargarLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('logs_sistema')
          .select()
          .order('fecha_hora', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar logs: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runHealthCheck() async {
    if (_isCheckingHealth) return;
    setState(() {
      _isCheckingHealth = true;
      _addConsoleLog('GET /api/health...');
    });

    final responsePayload = await _healthService.checkHealth();
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(responsePayload);

    if (mounted) {
      setState(() {
        _isCheckingHealth = false;
        _addConsoleLog('Response [${responsePayload['status']}]:\n$jsonString');
      });
      _cargarLogs(); // Refresca los logs en BD tras el health check
    }
  }

  void _addConsoleLog(String log) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    _consoleLogs.add('[$timestamp] $log');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: AppTheme.primaryGreen,
                      size: 32,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Consola de Auditoría y Logs del Sistema',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 1. Health Check Console
                _buildConsoleWidget(),

                const SizedBox(height: 28),

                // 2. Tabla de Logs de Auditoría
                _buildAuditLogTable(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleWidget() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  color: AppTheme.primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'API Health Check Console',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: _isCheckingHealth
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.grey, size: 18),
                  onPressed: _runHealthCheck,
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _consoleLogs.join('\n\n'),
                style: const TextStyle(
                  color: Color(0xFF4EC9B0),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Registros de Auditoría Recientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _cargarLogs,
                tooltip: 'Refrescar registros',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No hay registros de auditoría aún.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final nivel = log['nivel'] ?? 'INFO';

                IconData icon;
                Color color;

                if (nivel == 'ERROR') {
                  icon = Icons.error_outline;
                  color = Colors.red;
                } else if (nivel == 'WARNING') {
                  icon = Icons.warning_amber_outlined;
                  color = Colors.orange;
                } else {
                  icon = Icons.info_outline;
                  color = Colors.blue;
                }

                final categoria = log['categoria'] ?? 'GENERAL';
                final mensaje = log['mensaje'] ?? '';
                final fecha =
                    log['fecha_hora']?.toString().split('T').first ?? '';

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 0,
                  ),
                  leading: Icon(icon, color: color, size: 22),
                  title: Text(
                    '[$categoria] $mensaje',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Correo: ${log['email'] ?? 'N/A'} | IP: ${log['origen_ip'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    fecha,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
