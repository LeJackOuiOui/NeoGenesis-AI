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

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  String? _cargoSeleccionado;
  String? _avatarUrl;
  bool _isLoading = false;

  // Opciones para el cargo seleccionable
  final List<String> _listaCargos = [
    'Analista de Recursos Humanos',
    'Reclutador',
    'Responsable de Nómina',
    'Coordinador de Recursos Humanos',
    'Asistente de Recursos Humanos',
    'Empleado',
  ];

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

        if (data == null) {
        final metadata = supabase.auth.currentUser?.userMetadata ?? {};
        _nombreController.text = metadata['full_name']?.toString() ?? '';
        _correoController.text = supabase.auth.currentUser?.email ?? '';
        _telefonoController.text = metadata['phone']?.toString() ?? '';
        _cargoSeleccionado = _listaCargos.contains(metadata['position'])
          ? metadata['position'] as String
          : null;
        return;
        }

      _nombreController.text = data['nombre'] ?? '';
      _correoController.text = data['email'] ?? data['correo'] ?? '';
      _telefonoController.text = data['telefono'] ?? '';
      _avatarUrl = data['avatar_url'];

      if (_listaCargos.contains(data['cargo'])) {
        _cargoSeleccionado = data['cargo'];
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

  // Guardar o actualizar datos en Supabase
  Future<void> _guardarPerfil() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('profiles').upsert({
        'id': userId,
        'nombre': _nombreController.text,
        'email': _correoController.text,
        'cargo': _cargoSeleccionado,
        'telefono': _telefonoController.text,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente en Supabase.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar datos: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
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
                                _nombreController.text.isNotEmpty
                                    ? _nombreController.text[0].toUpperCase()
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
                              _nombreController.text.isEmpty
                                  ? 'Sin Nombre'
                                  : _nombreController.text,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _cargoSeleccionado ?? 'Sin Cargo asignado',
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

                // 2. Formulario de Datos Personales
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
                        builder: (context, constraints) {
                          bool esAncho = constraints.maxWidth > 600;
                          double widthFactor = esAncho
                              ? (constraints.maxWidth - 20) / 2
                              : constraints.maxWidth;

                          return Wrap(
                            spacing: 20,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: widthFactor,
                                child: _buildTextField(
                                  label: 'Nombre Completo',
                                  controller: _nombreController,
                                  icon: Icons.person_outline,
                                ),
                              ),
                              SizedBox(
                                width: widthFactor,
                                child: _buildTextField(
                                  label: 'Correo Electrónico',
                                  controller: _correoController,
                                  icon: Icons.email_outlined,
                                ),
                              ),
                              // Desplegable de Cargo Seleccionable
                              SizedBox(
                                width: widthFactor,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cargo / Rol',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      initialValue: _cargoSeleccionado,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                          Icons.work_outline,
                                          color: AppTheme.primaryGreen,
                                          size: 20,
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[200]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primaryGreen,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      hint: const Text('Selecciona un cargo'),
                                      items: _listaCargos.map((cargo) {
                                        return DropdownMenuItem(
                                          value: cargo,
                                          child: Text(cargo),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(
                                          () => _cargoSeleccionado = val,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: widthFactor,
                                child: _buildTextField(
                                  label: 'Teléfono',
                                  controller: _telefonoController,
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _guardarPerfil,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: const Text(
                            'Guardar Cambios',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
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
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
