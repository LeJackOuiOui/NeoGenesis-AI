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
  String _rol = 'usuario';
  String _nit = '';
  String _dv = '';
  String _direccion = '';
  String? _avatarUrl;
  bool _isLoading = false;
  String _verificationStatus = '';

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

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
        _rol = metadata['role']?.toString().toLowerCase() ?? 'usuario';
        return;
      }

      _nombre = _profileValue(data['nombre'], metadata['full_name']);
      _correo = _profileValue(
        data['email'] ?? data['correo'],
        supabase.auth.currentUser?.email,
      );
      _telefono = _profileValue(data['telefono'], metadata['phone']);

      final rawRol = _profileValue(
        data['role'] ?? data['rol'],
        metadata['role'],
      ).toLowerCase();
      if (['empresa', 'administrador', 'admin'].contains(rawRol)) {
        _rol = rawRol == 'admin' ? 'administrador' : rawRol;
      } else {
        _rol = 'usuario';
      }
      _verificationStatus =
          data['company_verification_status']?.toString() ?? 'pending';

      _nit = _profileValue(data['company_nit'], '');
      _dv = _profileValue(data['company_dv'], '');
      _direccion = _profileValue(data['company_address'], '');
      _avatarUrl = data['avatar_url'];
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

  Future<void> _mostrarModalEditar() async {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(text: _nombre);
    final telefonoController = TextEditingController(text: _telefono);
    final nitController = TextEditingController(text: _nit);
    final dvController = TextEditingController(text: _dv);
    final direccionController = TextEditingController(text: _direccion);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Editar Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'El nombre es obligatorio'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                  ),
                  if (_rol == 'empresa') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: nitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'NIT'),
                            validator: (val) {
                              if (_rol == 'empresa' &&
                                  (val == null || val.trim().isEmpty)) {
                                return 'Campo requerido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: dvController,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            decoration: const InputDecoration(
                              labelText: 'DV',
                              counterText: '',
                            ),
                            validator: (val) {
                              if (_rol == 'empresa' &&
                                  (val == null || val.trim().isEmpty)) {
                                return 'DV req.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: direccionController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección física',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) return;

                final updateData = {
                  'nombre': nombreController.text.trim(),
                  'telefono': telefonoController.text.trim(),
                  if (_rol == 'empresa') ...{
                    'company_nit': nitController.text.trim(),
                    'company_dv': dvController.text.trim(),
                    'company_address': direccionController.text.trim(),
                  },
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                };

                await supabase
                    .from('profiles')
                    .update(updateData)
                    .eq('id', userId);

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perfil actualizado correctamente'),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
                _cargarDatosPerfil();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al actualizar: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Perfil de Usuario',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _mostrarModalEditar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar Perfil'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

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
                            if (_rol == 'empresa' &&
                                _verificationStatus == 'verified') ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppTheme.primaryGreen,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
                        'Rol',
                        _rol[0].toUpperCase() + _rol.substring(1),
                        Icons.badge_outlined,
                      ),
                      _buildProfileItem(
                        'Teléfono',
                        _telefono.isEmpty ? 'No registrado' : _telefono,
                        Icons.phone_outlined,
                      ),

                      if (_rol == 'empresa') ...[
                        const Divider(height: 32),
                        const Text(
                          'Información Corporativa',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildProfileItem(
                          'NIT',
                          _nit.isEmpty
                              ? 'No registrado'
                              : '${_nit}${_dv.isNotEmpty ? ' - $_dv' : ''}',
                          Icons.business_outlined,
                        ),
                        _buildProfileItem(
                          'Dirección',
                          _direccion.isEmpty ? 'No registrada' : _direccion,
                          Icons.location_on_outlined,
                        ),
                      ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
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
      ),
    );
  }
}
