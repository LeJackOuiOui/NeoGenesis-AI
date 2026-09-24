import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../../main.dart';
import 'custom_otp_modal.dart'; // Importación del modal de OTP

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
  final List<Map<String, dynamic>> _empleados = [];
  bool get _isAdmin {
    final role =
        (supabase.auth.currentUser?.userMetadata?['role'] as String?)
            ?.toLowerCase() ??
        '';
    return role == 'administrador' || role == 'admin';
  }

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
                'estado': user.estado,
                'salarioBase': user.salarioBase,
                'tipoContrato': user.tipoContrato,
                'fechaIngreso': user.fechaIngreso,
                'fecha': _formatDate(user.fechaIngreso ?? user.creadoEn),
                'bajaLogica': user.bajaLogica,
              },
            ),
          );
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cargar el listado de usuarios.'),
          ),
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

  String _formatCurrency(num? value) {
    final amount = (value ?? 0).toDouble();
    return 'S/ ${amount.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final query = _searchController.text.trim().toLowerCase();
    return _empleados.where((employee) {
      final status = (employee['estado'] ?? '').toString();
      final matchesStatus =
          _selectedStatus == 'Todos' || status == _selectedStatus;
      final hayCoincidencia =
          query.isEmpty ||
          [
            employee['nombre'],
            employee['cargo'],
            employee['correo'],
            employee['tipoContrato'],
            employee['fecha'],
          ].any((value) => value.toString().toLowerCase().contains(query));
      return matchesStatus && hayCoincidencia;
    }).toList();
  }

  int _countByStatus(String status) {
    if (status == 'Todos') return _empleados.length;
    return _empleados
        .where((employee) => (employee['estado'] ?? '') == status)
        .length;
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
                          'Gestiona la información laboral básica del personal.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (_isAdmin) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showEmployeeDialog(),
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
                  ],
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth > 800
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
                          title: 'Bajas Lógicas',
                          value:
                              '${_empleados.where((employee) => employee['bajaLogica'] == true).length}',
                          icon: Icons.person_off_outlined,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
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
                      if (_isLoadingUsers)
                        const LinearProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por nombre, cargo o correo...',
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
                            _buildStatusFilter('Inactivo'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppTheme.lightGreenBg.withValues(alpha: 0.5),
                          ),
                          columns: [
                            DataColumn(
                              label: Text(
                                'Empleado',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Cargo',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Contrato',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Salario',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Estado',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Fecha Ingreso',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (_isAdmin) ...[
                              DataColumn(
                                label: Text(
                                  'Acciones',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                          rows: _filteredEmployees.map((item) {
                            final nombre = (item['nombre'] ?? '').toString();
                            final cargo = (item['cargo'] ?? '').toString();
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
                                          gradient: _avatarGradient(nombre),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _avatarInitial(nombre),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombre,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textDark,
                                              ),
                                            ),
                                            Text(
                                              (item['correo'] ?? '').toString(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(cargo.isEmpty ? 'Sin cargo' : cargo),
                                ),
                                DataCell(
                                  Text(
                                    (item['tipoContrato'] ?? 'Tiempo Completo')
                                        .toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(_formatCurrency(item['salarioBase'])),
                                ),
                                if (_isAdmin) ...[
                                  DataCell(_buildStatusSelector(item)),
                                ] else ...[
                                  DataCell(
                                    _buildStatusChip(
                                      item['estado'] ?? 'Activo',
                                    ),
                                  ),
                                ],
                                DataCell(
                                  Text(
                                    (item['fecha'] ?? 'Sin fecha').toString(),
                                  ),
                                ),
                                if (_isAdmin) ...[
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: AppTheme.primaryGreen,
                                          ),
                                          onPressed: () => _showEmployeeDialog(
                                            employee: item,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Baja lógica',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _deleteEmployee(item),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
    );
  }

  Widget _buildStatusSelector(Map<String, dynamic> employee) {
    final currentStatus = (employee['estado'] ?? 'Activo').toString();
    return PopupMenuButton<String>(
      tooltip: 'Cambiar estado',
      initialValue: currentStatus,
      onSelected: (status) async {
        final previousStatus = employee['estado'];
        setState(() => employee['estado'] = status);
        try {
          await _apiService.updateUserStatus(
            userId: employee['id'].toString(),
            status: status,
          );
        } catch (_) {
          if (!mounted) return;
          setState(() => employee['estado'] = previousStatus);
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
          _buildStatusChip(currentStatus),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }

  Future<void> _deleteEmployee(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString();
    if (id == null || id.isEmpty) return;

    if (id == supabase.auth.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puedes eliminar tu propia cuenta.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text(
          '¿Deseas eliminar definitivamente a ${employee['nombre']}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _apiService.deleteEmployee(userId: id);
      if (!mounted) return;
      setState(() => _empleados.removeWhere((item) => item['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario ${employee['nombre']} eliminado'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
    }
  }

  Future<void> _showEmployeeDialog({Map<String, dynamic>? employee}) async {
    final isEditing = employee != null;
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController(
      text: (employee?['nombre'] ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (employee?['correo'] ?? '').toString(),
    );
    final passwordController = TextEditingController();
    final salarioController = TextEditingController(
      text: ((employee?['salarioBase'] ?? 0) as num).toString(),
    );

    const roles = ['Administrador', 'Responsable RRHH', 'Empleado'];
    String selectedRole = (employee?['rol'] ?? 'Empleado').toString();

    const cargoOptions = [
      'Administrador',
      'Responsable RRHH',
      'Analista de Recursos Humanos',
      'Reclutador',
      'Responsable de Nómina',
      'Coordinador de Recursos Humanos',
      'Asistente de Recursos Humanos',
      'Empleado',
      'Analista Contable',
      'Diseñador UX/UI',
      'Desarrollador Full Stack',
      'Especialista en Nómina',
      'Líder de Selección',
    ];
    final selectedCargos = (employee?['cargo'] ?? '')
        .toString()
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    const contratoOptions = [
      'Tiempo Completo',
      'Medio Tiempo',
      'Por Horas',
      'Contrato Temporal',
    ];
    String selectedContrato = (employee?['tipoContrato'] ?? 'Tiempo Completo')
        .toString();
    DateTime selectedDate =
        (employee?['fechaIngreso'] as DateTime?) ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar empleado' : 'Registrar empleado'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombreController,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el nombre';
                        }
                        if (RegExp(r'\d').hasMatch(value)) {
                          return 'El nombre no puede contener números';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      enabled: !isEditing,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo institucional *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el correo';
                        }
                        if (!ApiService.isValidGmailEmail(value)) {
                          return 'Usa un Gmail válido';
                        }
                        return null;
                      },
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña inicial *',
                          helperText:
                              'El empleado usará esta contraseña para iniciar sesión.',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una contraseña';
                          }
                          if (value.length < 6) {
                            return 'Usa al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cargos *',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: cargoOptions.map((cargo) {
                        final selected = selectedCargos.contains(cargo);
                        return FilterChip(
                          label: Text(cargo),
                          selected: selected,
                          onSelected: (_) {
                            setDialogState(() {
                              if (selected) {
                                selectedCargos.remove(cargo);
                              } else {
                                selectedCargos.add(cargo);
                              }
                            });
                          },
                          selectedColor: AppTheme.primaryGreen.withValues(
                            alpha: 0.16,
                          ),
                          checkmarkColor: AppTheme.primaryGreen,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppTheme.primaryGreen
                                : AppTheme.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: salarioController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'\d*\.?\d')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Salario base *',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa el salario';
                        }
                        final parsed = double.tryParse(value);
                        if (parsed == null || parsed <= 0) {
                          return 'Salario inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: contratoOptions.contains(selectedContrato)
                          ? selectedContrato
                          : contratoOptions.first,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de contrato *',
                      ),
                      items: contratoOptions
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedContrato = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fecha de ingreso'),
                      subtitle: Text(_formatDate(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: roles.contains(selectedRole)
                          ? selectedRole
                          : roles.last,
                      decoration: const InputDecoration(labelText: 'Rol *'),
                      items: roles
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedRole = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedCargos.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selecciona al menos un cargo.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final cargoValue = selectedCargos.toList()..sort();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (isEditing) {
                    await _apiService.updateEmployee(
                      userId: employee['id'].toString(),
                      nombre: nombreController.text,
                      cargo: cargoValue.join(', '),
                      salarioBase: double.parse(salarioController.text),
                      tipoContrato: selectedContrato,
                      fechaIngreso: selectedDate,
                    );
                  } else {
                    final email = emailController.text.trim();

                    final registration = await _apiService.registerHrUser(
                      nombre: nombreController.text,
                      correo: email,
                      telefono: '',
                      cargo: cargoValue.join(', '),
                      rol: selectedRole,
                      password: passwordController.text,
                      estado: 'Activo',
                    );
                    final userId = registration.user.id;
                    if (userId == null || userId.isEmpty) {
                      throw Exception(
                        'Supabase no devolvió el identificador del usuario.',
                      );
                    }
                    await _apiService.updateEmployee(
                      userId: userId,
                      nombre: nombreController.text,
                      cargo: cargoValue.join(', '),
                      salarioBase: double.parse(salarioController.text),
                      tipoContrato: selectedContrato,
                      fechaIngreso: selectedDate,
                    );
                  }

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  await _loadUsers();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isEditing
                            ? 'Empleado actualizado correctamente.'
                            : 'Empleado registrado correctamente.',
                      ),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('No se pudo guardar: $error'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: Text(isEditing ? 'Guardar cambios' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    nombreController.dispose();
    emailController.dispose();
    passwordController.dispose();
    salarioController.dispose();
  }

  LinearGradient _avatarGradient(String name) {
    final colors = <List<Color>>[
      [AppTheme.primaryGreen, const Color(0xFF087F5B)],
      [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
      [const Color(0xFF7B1FA2), const Color(0xFFBA68C8)],
    ];
    final selected =
        colors[(name.isEmpty ? 0 : name.codeUnitAt(0)) % colors.length];
    return LinearGradient(colors: selected);
  }

  String _avatarInitial(String? name) {
    final trimmedName = name?.trim() ?? '';
    return trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();
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

  Widget _buildStatusChip(String estado) {
    Color bg;
    Color fg;

    switch (estado) {
      case 'Activo':
        bg = AppTheme.lightGreenBg;
        fg = AppTheme.primaryGreen;
        break;
      case 'Inactivo':
        bg = Colors.red[50]!;
        fg = Colors.red[700]!;
        break;
      default:
        bg = Colors.amber[50]!;
        fg = Colors.amber[800]!;
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
}
