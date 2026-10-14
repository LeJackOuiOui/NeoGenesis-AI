import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../main.dart';

class ViewRegistros extends StatefulWidget {
  const ViewRegistros({super.key});

  @override
  State<ViewRegistros> createState() => _ViewRegistrosState();
}

class _ViewRegistrosState extends State<ViewRegistros> {
  final ApiService _apiService = ApiService(supabase);
  bool _isLoading = false;
  final List<Map<String, dynamic>> _empresas = [];

  @override
  void initState() {
    super.initState();
    _loadEmpresas();
  }

  Future<void> _loadEmpresas() async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos todos los perfiles y filtramos solo los que son empresas
      final users = await _apiService.fetchUsers();
      if (!mounted) return;

      setState(() {
        _empresas
          ..clear()
          ..addAll(
            users
                .where((user) {
                  final rol = user.rol.toLowerCase();
                  final nit = (user.companyNit ?? '').trim();
                  return rol == 'empresa' || nit.isNotEmpty;
                })
                .map(
                  (user) => {
                    'id': user.id ?? '',
                    'nombre': user.nombre,
                    'correo': user.correo,
                    'telefono': user.telefono ?? 'No registrado',
                    'role': user.rol,
                    'companyNit': user.companyNit ?? '',
                    'companyDv': user.companyDv ?? '',
                    'companyAddress': user.companyAddress ?? 'No registrada',
                    'companyVerificationStatus':
                        user.companyVerificationStatus ?? 'pending',
                    'isRRHH': user.isRRHH,
                  },
                ),
          );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar empresas: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 1. MODAL VER INFORMACIÓN
  void _verInformacion(Map<String, dynamic> empresa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(empresa['nombre'] ?? 'Información de Empresa'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Razón Social / Nombre:', empresa['nombre']),
              _buildInfoRow('Correo:', empresa['correo']),
              _buildInfoRow('Teléfono:', empresa['telefono']),
              _buildInfoRow(
                'NIT:',
                '${empresa['companyNit']}${empresa['companyDv'].isNotEmpty ? ' - ${empresa['companyDv']}' : ''}',
              ),
              _buildInfoRow('Dirección:', empresa['companyAddress']),
              _buildInfoRow(
                'Estado:',
                empresa['companyVerificationStatus'] == 'verified'
                    ? 'Verificada'
                    : 'Pendiente',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  // 2. VERIFICAR EMPRESA (Actualiza status a verified e isRRHH a true)
  Future<void> _verificarEmpresa(Map<String, dynamic> empresa) async {
    final userId = empresa['id']?.toString();
    if (userId == null) return;

    try {
      await supabase
          .from('profiles')
          .update({
            'company_verification_status': 'verified',
            'is_rrhh': true,
            'role': 'empresa',
          })
          .eq('id', userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Empresa verificada y habilitada como RRHH correctamente.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      _loadEmpresas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al verificar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 3. RECHAZAR EMPRESA (Elimina la cuenta)
  Future<void> _rechazarEmpresa(Map<String, dynamic> empresa) async {
    final userId = empresa['id']?.toString();
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rechazar empresa'),
        content: Text(
          '¿Estás seguro de rechazar y eliminar definitivamente la cuenta de ${empresa['nombre']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar y Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _apiService.deleteEmployee(userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa rechazada y cuenta eliminada correctamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _loadEmpresas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verificación de Empresas',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revisa, valida o rechaza las solicitudes de registro corporativo.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 28),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const LinearProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      const SizedBox(height: 12),
                      _empresas.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Center(
                                child: Text(
                                  'No hay empresas pendientes o registradas.',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppTheme.lightGreenBg.withValues(alpha: 0.5),
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Empresa',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'NIT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Correo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Estado',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Acciones',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: _empresas.map((empresa) {
                                  final isVerified =
                                      empresa['companyVerificationStatus'] ==
                                      'verified';
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          empresa['nombre'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${empresa['companyNit']}${empresa['companyDv'].isNotEmpty ? ' - ${empresa['companyDv']}' : ''}',
                                        ),
                                      ),
                                      DataCell(Text(empresa['correo'] ?? '')),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isVerified
                                                ? AppTheme.lightGreenBg
                                                : Colors.orange[50],
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isVerified
                                                ? 'Verificada'
                                                : 'Pendiente',
                                            style: TextStyle(
                                              color: isVerified
                                                  ? AppTheme.primaryGreen
                                                  : Colors.orange[800],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _verInformacion(empresa),
                                              icon: const Icon(
                                                Icons.info_outline,
                                                size: 16,
                                              ),
                                              label: const Text('Ver Info'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppTheme.textDark,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (!isVerified) ...[
                                              ElevatedButton.icon(
                                                onPressed: () =>
                                                    _verificarEmpresa(empresa),
                                                icon: const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                ),
                                                label: const Text('Verificar'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTheme.primaryGreen,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _rechazarEmpresa(empresa),
                                              icon: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.red,
                                              ),
                                              label: const Text(
                                                'Rechazar',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
