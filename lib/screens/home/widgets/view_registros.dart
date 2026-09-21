import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../main.dart';

class ViewRegistros extends StatefulWidget {
  const ViewRegistros({super.key});

  @override
  State<ViewRegistros> createState() => _ViewRegistrosState();
}

class _ViewRegistrosState extends State<ViewRegistros> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService(supabase);
  String _selectedStatus = 'Todos';
  bool _isLoadingUsers = false;

  // Lista simulada de empleados
  final List<Map<String, String>> _empleados = [
    {
      'nombre': 'Carlos Rodríguez',
      'cargo': 'Desarrollador Full Stack',
      'departamento': 'Tecnología',
      'estado': 'Activo',
      'fecha': '15/01/2024',
    },
    {
      'nombre': 'Ana María Gómez',
      'cargo': 'Líder de Selección',
      'departamento': 'Recursos Humanos',
      'estado': 'Activo',
      'fecha': '02/03/2023',
    },
    {
      'nombre': 'Felipe Mendoza',
      'cargo': 'Analista Contable',
      'departamento': 'Finanzas',
      'estado': 'En Vacaciones',
      'fecha': '10/11/2022',
    },
    {
      'nombre': 'Laura Sofia Torres',
      'cargo': 'Diseñadora UX/UI',
      'departamento': 'Tecnología',
      'estado': 'Activo',
      'fecha': '20/05/2024',
    },
    {
      'nombre': 'Javier Ruiz',
      'cargo': 'Especialista en Nómina',
      'departamento': 'Recursos Humanos',
      'estado': 'Inactivo',
      'fecha': '01/08/2021',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await _apiService.fetchUsers();
      if (!mounted) return;
      setState(() {
        _empleados
          ..clear()
          ..addAll(
            users.map(
              (user) => {
                'id': user.id ?? '',
                'nombre': user.nombre,
                'correo': user.correo,
                'cargo': user.cargo,
                'rol': user.rol,
                'departamento': 'Recursos Humanos',
                'estado': user.estado,
                'fecha': _formatDate(user.creadoEn),
              },
            ),
          );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el listado de usuarios.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredEmployees {
    final query = _searchController.text.trim().toLowerCase();
    return _empleados.where((employee) {
      final matchesStatus =
          _selectedStatus == 'Todos' || employee['estado'] == _selectedStatus;
      final matchesSearch =
          query.isEmpty ||
          employee.values.any((value) => value.toLowerCase().contains(query));
      return matchesStatus && matchesSearch;
    }).toList();
  }

  int _countByStatus(String status) {
    if (status == 'Todos') return _empleados.length;
    return _empleados.where((employee) => employee['estado'] == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado de la Sección
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Registro de Personal',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gestiona los colaboradores y su información dentro de la plataforma.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _showNewEmployeeDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Nuevo Empleado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // 1. TARJETAS DE MÉTRICAS (KPIs)
                    // ==========================================
                    LayoutBuilder(
                      builder: (context, constraints) {
                        double cardWidth = constraints.maxWidth > 800
                            ? (constraints.maxWidth - 32) / 3
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildKpiCard(
                              title: 'Total Colaboradores',
                              value: '${_empleados.length}',
                              icon: Icons.people_alt_outlined,
                              width: cardWidth,
                            ),
                            _buildKpiCard(
                              title: 'Personal Activo',
                              value: '${_countByStatus('Activo')}',
                              icon: Icons.check_circle_outline,
                              width: cardWidth,
                            ),
                            _buildKpiCard(
                              title: 'Departamentos',
                              value: '${_empleados.map((employee) => employee['departamento']).toSet().length}',
                              icon: Icons.business_outlined,
                              width: cardWidth,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ==========================================
                    // 2. TABLA Y BARRA DE BÚSQUEDA
                    // ==========================================
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
                          if (_isLoadingUsers)
                            const LinearProgressIndicator(
                              color: AppTheme.primaryGreen,
                            ),
                          const SizedBox(height: 12),
                          // Barra superior con campo de búsqueda
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Buscar por nombre, cargo o departamento...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: AppTheme.primaryGreen,
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
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
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(
                                  Icons.filter_list,
                                  color: AppTheme.textDark,
                                ),
                                tooltip: 'Filtrar',
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusFilter('Todos'),
                                _buildStatusFilter('Activo'),
                                _buildStatusFilter('En Vacaciones'),
                                _buildStatusFilter('Inactivo'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Tabla de Datos Responsiva
                          SizedBox(
                            width: double.infinity,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppTheme.lightGreenBg.withValues(alpha: 0.5),
                              ),
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 65,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Empleado',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Departamento',
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
                                    'Fecha Ingreso',
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
                              rows: _filteredEmployees.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: _avatarGradient(
                                                item['nombre']!,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              item['nombre']![0].toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item['nombre']!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textDark,
                                                ),
                                              ),
                                              Text(
                                                item['cargo']!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                'Rol: ${item['rol'] ?? 'Empleado'}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(item['departamento']!)),
                                    DataCell(_buildStatusSelector(item)),
                                    DataCell(Text(item['fecha']!)),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () =>
                                                _abrirModalEditar(item),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _confirmarEliminar(item),
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _avatarGradient(String name) {
    final colors = <List<Color>>[
      [AppTheme.primaryGreen, const Color(0xFF087F5B)],
      [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
      [const Color(0xFF7B1FA2), const Color(0xFFBA68C8)],
    ];
    final selected = colors[name.codeUnitAt(0) % colors.length];
    return LinearGradient(colors: selected);
  }

  Widget _buildStatusFilter(String status) {
    final selected = _selectedStatus == status;
    final count = _countByStatus(status);
    return ChoiceChip(
      label: Text('$status ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _selectedStatus = status),
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(color: Colors.grey[300]!),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildStatusSelector(Map<String, String> employee) {
    return PopupMenuButton<String>(
      tooltip: 'Cambiar estado',
      initialValue: employee['estado'],
      onSelected: (status) async {
        final previousStatus = employee['estado'];
        setState(() => employee['estado'] = status);
        try {
          await _apiService.updateUserStatus(
            userId: employee['id']!,
            status: status,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() => employee['estado'] = previousStatus!);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo actualizar el estado.')),
          );
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Activo', child: Text('Activo')),
        PopupMenuItem(value: 'En Vacaciones', child: Text('En Vacaciones')),
        PopupMenuItem(value: 'Inactivo', child: Text('Inactivo')),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusChip(employee['estado']!),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(Map<String, String> employee) async {
    final nombre = employee['nombre']!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desactivar usuario'),
        content: Text(
          '¿Estás seguro de que deseas desactivar a $nombre? No podrá iniciar sesión mientras esté inactivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    try {
      await _apiService.updateUserStatus(
        userId: employee['id']!,
        status: 'Inactivo',
      );
      if (!mounted) return;
      setState(() => employee['estado'] = 'Inactivo');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario $nombre desactivado'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo desactivar el usuario.')),
      );
    }
  }

  Future<void> _abrirModalEditar(Map<String, String> employee) async {
    final nameController = TextEditingController(text: employee['nombre']);
    final positionController = TextEditingController(text: employee['cargo']);
    var selectedRole = employee['rol'] ?? 'Empleado';
    var selectedDepartment = employee['departamento']!;
    const departments = ['Tecnología', 'Recursos Humanos', 'Finanzas'];
    const roles = ['Administrador', 'Responsable RRHH', 'Empleado'];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Editar: ${employee['nombre']}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(labelText: 'Cargo'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: departments.contains(selectedDepartment)
                      ? selectedDepartment
                      : null,
                  decoration: const InputDecoration(labelText: 'Departamento'),
                  items: departments
                      .map(
                        (department) => DropdownMenuItem(
                          value: department,
                          child: Text(department),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedDepartment = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: roles.contains(selectedRole) ? selectedRole : null,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: roles
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedRole = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    positionController.text.trim().isEmpty) {
                  return;
                }
                try {
                  final updated = await _apiService.updateUser(
                    userId: employee['id']!,
                    nombre: nameController.text,
                    cargo: positionController.text,
                    rol: selectedRole,
                    estado: employee['estado']!,
                  );
                  if (!context.mounted) return;
                  setState(() {
                    employee['nombre'] = updated.nombre;
                    employee['cargo'] = updated.cargo;
                    employee['rol'] = updated.rol;
                    employee['departamento'] = selectedDepartment;
                  });
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Información actualizada correctamente'),
                      backgroundColor: AppTheme.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo actualizar el usuario.')),
                    );
                  }
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    positionController.dispose();
  }

  Future<void> _showNewEmployeeDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedCargo = 'Analista de Recursos Humanos';
    var selectedRole = 'Empleado';
    const cargos = [
      'Analista de Recursos Humanos',
      'Reclutador',
      'Responsable de Nómina',
      'Coordinador de Recursos Humanos',
      'Asistente de Recursos Humanos',
      'Empleado',
    ];
    const roles = ['Administrador', 'Responsable RRHH', 'Empleado'];
    var isSaving = false;
    var obscurePassword = true;
    var obscureConfirmPassword = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Registrar usuario de RRHH'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'),
                        ),
                      ],
                      decoration: const InputDecoration(labelText: 'Nombre completo *'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Ingresa el nombre';
                        if (RegExp(r'\d').hasMatch(value)) return 'El nombre no puede contener números';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Teléfono *'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Ingresa el teléfono';
                        if (value.replaceAll(RegExp(r'\D'), '').length < 7) {
                          return 'Ingresa un teléfono válido';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Contraseña *',
                        helperText: 'Mínimo 6 caracteres',
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Ingresa la contraseña';
                        if (value.length < 6) return 'Usa mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Confirmar contraseña *',
                        suffixIcon: IconButton(
                          tooltip: obscureConfirmPassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => obscureConfirmPassword = !obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (value) => value != passwordController.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCargo,
                      decoration: const InputDecoration(
                        labelText: 'Cargo *',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: cargos
                          .map((cargo) => DropdownMenuItem(value: cargo, child: Text(cargo)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedCargo = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(labelText: 'Rol *'),
                      items: roles
                          .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedRole = value);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: isSaving || passwordController.text.length < 6
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final result = await _apiService.registerHrUser(
                          nombre: nameController.text,
                          correo: emailController.text,
                          telefono: phoneController.text,
                          cargo: selectedCargo,
                          rol: selectedRole,
                          password: passwordController.text,
                          estado: 'Activo',
                        );
                        if (!context.mounted) return;
                        setState(() {
                          _empleados.insert(0, {
                            'nombre': result.user.nombre,
                            'correo': result.user.correo,
                            'cargo': result.user.cargo,
                            'rol': result.user.rol,
                            'departamento': 'Recursos Humanos',
                            'estado': result.user.estado,
                            'fecha': _formatDate(result.user.creadoEn),
                          });
                        });
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Usuario creado. Sus credenciales fueron enviadas por correo.'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      } on DuplicateUserException {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('El correo institucional ya está registrado.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      } catch (error) {
                        setDialogState(() => isSaving = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('No se pudo crear el usuario: $error'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: const Text('Crear usuario'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  // Tarjeta de KPI
  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 26),
          ),
        ],
      ),
    );
  }

  // Chip de Estado con colores condicionales
  Widget _buildStatusChip(String estado) {
    Color bg;
    Color fg;

    switch (estado) {
      case 'Activo':
        bg = AppTheme.lightGreenBg;
        fg = AppTheme.primaryGreen;
        break;
      case 'En Vacaciones':
        bg = Colors.amber[50]!;
        fg = Colors.amber[800]!;
        break;
      default:
        bg = Colors.red[50]!;
        fg = Colors.red[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
