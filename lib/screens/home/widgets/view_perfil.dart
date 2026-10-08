import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';

class ViewPerfil extends StatefulWidget {
  const ViewPerfil({super.key});

  @override
  State<ViewPerfil> createState() => _ViewPerfilState();
}

class _ViewPerfilState extends State<ViewPerfil> {
  final supabase = Supabase.instance.client;

  String _nombre = '';
  String _correo = '';
  String _telefono = '';
  String _cargo = '';
  String _rol = '';
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  // Cargar datos desde Supabase
  Future<void> _cargarDatosPerfil() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      final metadata = supabase.auth.currentUser?.userMetadata ?? {};

      if (data == null) {
        _nombre = metadata['full_name']?.toString() ?? '';
        _correo = supabase.auth.currentUser?.email ?? '';
        _telefono = metadata['phone']?.toString() ?? '';
        _cargo = metadata['position']?.toString() ?? '';
        _rol = metadata['role']?.toString() ?? '';
        return;
      }

      final nombre = _profileValue(data['nombre'], metadata['full_name']);
      final correo = _profileValue(
        data['email'] ?? data['correo'],
        supabase.auth.currentUser?.email,
      );
      final telefono = _profileValue(data['telefono'], metadata['phone']);
      final cargo = _profileValue(data['cargo'], metadata['position']);
      final rol = _profileValue(data['role'] ?? data['rol'], metadata['role']);

      _nombre = nombre;
      _correo = correo;
      _telefono = telefono;
      _avatarUrl = data['avatar_url'];
      _cargo = cargo;
      _rol = rol;

      final missingProfileData = <String, dynamic>{};
      if (_isEmpty(data['nombre']) && nombre.isNotEmpty) {
        missingProfileData['nombre'] = nombre;
      }
      if (_isEmpty(data['telefono']) && telefono.isNotEmpty) {
        missingProfileData['telefono'] = telefono;
      }
      if (_isEmpty(data['cargo']) && cargo.isNotEmpty) {
        missingProfileData['cargo'] = cargo;
      }
      if (_isEmpty(data['role'] ?? data['rol']) && rol.isNotEmpty) {
        missingProfileData['role'] = rol;
      }
      if (missingProfileData.isNotEmpty) {
        await supabase
            .from('profiles')
            .update(missingProfileData)
            .eq('id', userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar perfil: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _profileValue(dynamic profileValue, dynamic metadataValue) {
    final value = profileValue?.toString().trim() ?? '';
    return value.isNotEmpty ? value : metadataValue?.toString().trim() ?? '';
  }

  bool _isEmpty(dynamic value) =>
      value == null || value.toString().trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil de Usuario',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 28),

                // 1. Encabezado con Avatar desde URL
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppTheme.lightGreenBg,
                        backgroundImage:
                            _avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null || _avatarUrl!.isEmpty
                            ? Text(
                                _nombre.isNotEmpty
                                    ? _nombre[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombre.isEmpty ? 'Sin Nombre' : _nombre,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _cargo.isEmpty ? 'Sin cargo asignado' : _cargo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Los datos se diligencian al crear la cuenta. El administrador los edita desde el CRUD.
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => Column(
                          children: [
                            _buildProfileItem(
                              'Nombre completo',
                              _nombre,
                              Icons.person_outline,
                            ),
                            _buildProfileItem(
                              'Correo electrónico',
                              _correo,
                              Icons.email_outlined,
                            ),
                            _buildProfileItem(
                              'Cargo',
                              _cargo,
                              Icons.work_outline,
                            ),
                            _buildProfileItem(
                              'Rol',
                              _rol,
                              Icons.badge_outlined,
                            ),
                            _buildProfileItem(
                              'Teléfono',
                              _telefono,
                              Icons.phone_outlined,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildOptionCard(
                                    Icons.lock_outline,
                                    'Seguridad',
                                    'Cambiar contraseña',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildOptionCard(
                                    Icons.notifications_none,
                                    'Notificaciones',
                                    'Preferencias de avisos',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildOptionCard(
                              Icons.help_outline,
                              'Centro de ayuda',
                              'Soporte de la plataforma',
                            ),
                          ],
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

  Widget _buildProfileItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(color: AppTheme.textDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGreenBg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.primaryGreen),
        ],
      ),
    );
  }
}
