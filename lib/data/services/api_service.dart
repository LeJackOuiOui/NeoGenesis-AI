import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class DuplicateUserException implements Exception {
  const DuplicateUserException();
}

class UserRegistrationResult {
  final UserModel user;
  final String initialPassword;

  const UserRegistrationResult({
    required this.user,
    required this.initialPassword,
  });
}

class ApiService {
  final SupabaseClient client;

  const ApiService(this.client);

  // ==========================================
  // MÉTODOS DE AUTENTICACIÓN (LOGIN & AUTH)
  // ==========================================

  /// Inicia sesión con correo y contraseña.
  /// Retorna un objeto [AuthResponse] que contiene la sesión y el usuario autenticado.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return response;
  }

  /// Obtiene los datos del perfil ('profiles') del usuario autenticado actualmente.
  Future<UserModel?> getCurrentUserProfile() async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return null;

    try {
      final row = await client
          .from('profiles')
          .select(
            'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
          )
          .eq('id', currentUser.id)
          .maybeSingle();

      if (row == null) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) rethrow;

      final row = await client
          .from('profiles')
          .select('id, nombre, email, cargo, role, estado, created_at')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (row == null) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    }
  }

  /// Inicia sesión con el proveedor de OAuth de Google.
  Future<bool> loginWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback',
    );
  }

  /// Cierra la sesión activa en el dispositivo.
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ==========================================
  // UTILIDADES Y VALIDACIONES
  // ==========================================

  static bool isValidGmailEmail(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return RegExp(
      r'^[a-z0-9._%+\-]+@(gmail|googlemail)\.com$',
    ).hasMatch(normalized);
  }

  static Map<String, dynamic> buildEmployeeUpdatePayload({
    required String nombre,
    required String cargo,
    required double salarioBase,
    required String tipoContrato,
    required DateTime fechaIngreso,
    required bool includeSalaryFields,
  }) {
    final payload = <String, dynamic>{
      'nombre': nombre.trim(),
      'cargo': cargo.trim(),
      'tipo_contrato': tipoContrato.trim(),
      'fecha_ingreso': fechaIngreso.toIso8601String().split('T').first,
    };
    if (includeSalaryFields) {
      payload['salario_base'] = salarioBase;
    }
    return payload;
  }

  static bool _isMissingColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '42703' ||
        error.code == 'PGRST204' ||
        message.contains('does not exist') ||
        (message.contains('could not find the') && message.contains('column'));
  }

  static bool _isRlsError(PostgrestException error) {
    return error.code == '42501' ||
        error.message.toLowerCase().contains('row-level security policy');
  }

  // ==========================================
  // GESTIÓN DE EMPLEADOS / USUARIOS
  // ==========================================

  Future<List<UserModel>> fetchEmployees() async {
    try {
      final rows = await client
          .from('profiles')
          .select(
            'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
          )
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => UserModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      final rows = await client
          .from('profiles')
          .select('id, nombre, email, cargo, role, estado, created_at')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((row) => UserModel.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    }
  }

  Future<List<UserModel>> fetchUsers() async => fetchEmployees();

  Future<UserRegistrationResult> registerHrUser({
    required String nombre,
    required String correo,
    required String telefono,
    required String cargo,
    required String rol,
    required String password,
    required String estado,
  }) async {
    if (client.auth.currentSession == null) {
      throw Exception(
        'Debes iniciar sesión como Administrador o Responsable RRHH para crear empleados.',
      );
    }
    final normalizedEmail = correo.trim().toLowerCase();
    if (!isValidGmailEmail(normalizedEmail)) {
      throw Exception('El correo debe ser de Gmail o Google Mail.');
    }
    final existing = await client
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .maybeSingle();

    if (existing != null) throw const DuplicateUserException();

    final response = await client.functions.invoke(
      'create-hr-user',
      body: {
        'name': nombre.trim(),
        'email': normalizedEmail,
        'phone': telefono.trim(),
        'position': cargo.trim(),
        'role': 'Empleado',
        'password': password,
        'status': estado,
      },
    );

    final rawData = response.data;
    if (rawData is! Map || rawData['profile'] is! Map) {
      throw Exception(
        'Supabase no devolvió el perfil creado. Despliega la función create-hr-user.',
      );
    }
    final data = Map<String, dynamic>.from(rawData);
    final user = UserModel.fromMap(
      Map<String, dynamic>.from(data['profile'] as Map),
    );

    return UserRegistrationResult(user: user, initialPassword: password);
  }

  Future<UserModel> upsertEmployeeByEmail({
    required String nombre,
    required String email,
    required String cargo,
    required double salarioBase,
    required String tipoContrato,
    required DateTime fechaIngreso,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    Map<String, dynamic>? current;
    try {
      current = await client
          .from('profiles')
          .select(
            'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
          )
          .eq('email', normalizedEmail)
          .maybeSingle();
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      current = await client
          .from('profiles')
          .select('id, nombre, email, cargo, role, estado, created_at')
          .eq('email', normalizedEmail)
          .maybeSingle();
    }

    if (current == null) {
      if (!isValidGmailEmail(normalizedEmail)) {
        throw Exception(
          'El correo debe ser un Gmail válido para registrar un nuevo empleado.',
        );
      }
      try {
        final insert = await client
            .from('profiles')
            .insert({
              'nombre': nombre.trim(),
              'email': normalizedEmail,
              'cargo': cargo.trim(),
              'role': 'Empleado',
              'estado': 'Activo',
              'tipo_contrato': tipoContrato.trim(),
              'fecha_ingreso': fechaIngreso.toIso8601String().split('T').first,
              'salario_base': salarioBase,
              'baja_logica': false,
            })
            .select(
              'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
            )
            .single();
        return UserModel.fromMap(Map<String, dynamic>.from(insert));
      } on PostgrestException catch (error) {
        if (_isRlsError(error)) {
          throw Exception(
            'Falta aplicar en Supabase la política de inserción para Administradores/RRHH.',
          );
        }
        if (!_isMissingColumnError(error)) rethrow;
        final fallback = await client
            .from('profiles')
            .insert({
              'nombre': nombre.trim(),
              'email': normalizedEmail,
              'cargo': cargo.trim(),
              'role': 'Empleado',
              'estado': 'Activo',
            })
            .select('id, nombre, email, cargo, role, estado, created_at')
            .single();
        return UserModel.fromMap(Map<String, dynamic>.from(fallback));
      }
    }

    return updateEmployee(
      userId: current['id'].toString(),
      nombre: nombre,
      cargo: cargo,
      salarioBase: salarioBase,
      tipoContrato: tipoContrato,
      fechaIngreso: fechaIngreso,
    );
  }

  Future<UserModel> createEmployee({
    required String userId,
    required String nombre,
    required String cargo,
    required double salarioBase,
    required String tipoContrato,
    required DateTime fechaIngreso,
  }) async {
    final payload = buildEmployeeUpdatePayload(
      nombre: nombre,
      cargo: cargo,
      salarioBase: salarioBase,
      tipoContrato: tipoContrato,
      fechaIngreso: fechaIngreso,
      includeSalaryFields: true,
    );
    payload['role'] = 'Empleado';
    payload['estado'] = 'Activo';
    payload['baja_logica'] = false;

    try {
      final row = await client
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select(
            'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
          )
          .single();
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      final fallback = <String, dynamic>{
        'nombre': nombre.trim(),
        'cargo': cargo.trim(),
        'role': 'Empleado',
        'estado': 'Activo',
        'tipo_contrato': tipoContrato.trim(),
        'fecha_ingreso': fechaIngreso.toIso8601String().split('T').first,
      };
      final row = await client
          .from('profiles')
          .update(fallback)
          .eq('id', userId)
          .select('id, nombre, email, cargo, role, estado, created_at')
          .single();
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    }
  }

  Future<UserModel> updateEmployee({
    required String userId,
    required String nombre,
    required String cargo,
    required double salarioBase,
    required String tipoContrato,
    required DateTime fechaIngreso,
  }) async {
    final payload = buildEmployeeUpdatePayload(
      nombre: nombre,
      cargo: cargo,
      salarioBase: salarioBase,
      tipoContrato: tipoContrato,
      fechaIngreso: fechaIngreso,
      includeSalaryFields: true,
    );
    try {
      final row = await client
          .from('profiles')
          .update(payload)
          .eq('id', userId)
          .select(
            'id, nombre, email, cargo, role, estado, created_at, salario_base, tipo_contrato, fecha_ingreso, baja_logica',
          )
          .single();
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      final fallback = buildEmployeeUpdatePayload(
        nombre: nombre,
        cargo: cargo,
        salarioBase: salarioBase,
        tipoContrato: tipoContrato,
        fechaIngreso: fechaIngreso,
        includeSalaryFields: false,
      );
      final row = await client
          .from('profiles')
          .update(fallback)
          .eq('id', userId)
          .select('id, nombre, email, cargo, role, estado, created_at')
          .single();
      return UserModel.fromMap(Map<String, dynamic>.from(row));
    }
  }

  Future<void> deactivateEmployee({required String userId}) async {
    try {
      await client
          .from('profiles')
          .update({'estado': 'Inactivo', 'baja_logica': true})
          .eq('id', userId);
    } on PostgrestException catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      await client
          .from('profiles')
          .update({'estado': 'Inactivo'})
          .eq('id', userId);
    }
  }

  Future<void> updateUserStatus({
    required String userId,
    required String status,
  }) async {
    final profile = await client
        .from('profiles')
        .select('nombre, cargo, role')
        .eq('id', userId)
        .single();
    await updateUser(
      userId: userId,
      nombre: profile['nombre'] as String? ?? '',
      cargo: profile['cargo'] as String? ?? '',
      rol: profile['role'] as String? ?? 'Empleado',
      estado: status,
    );
  }

  Future<UserModel> updateUser({
    required String userId,
    required String nombre,
    required String cargo,
    required String rol,
    required String estado,
  }) async {
    final response = await client.rpc(
      'admin_update_user',
      params: {
        'p_user_id': userId,
        'p_nombre': nombre.trim(),
        'p_cargo': cargo.trim(),
        'p_role': rol,
        'p_estado': estado,
      },
    );
    if (response is! Map) {
      throw Exception('Supabase no devolvió el usuario actualizado.');
    }
    return UserModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ==========================================
  // OTP (ONE-TIME PASSWORD)
  // ==========================================

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    final response = await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.signup,
    );
    return response;
  }

  Future<void> resendOtp(String email) async {
    await client.auth.resend(type: OtpType.signup, email: email.trim());
  }
}
