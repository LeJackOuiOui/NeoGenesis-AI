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

	Future<List<UserModel>> fetchUsers() async {
		final rows = await client
				.from('profiles')
				.select('id, nombre, email, cargo, role, estado, created_at')
				.order('created_at', ascending: false);
		return (rows as List)
				.map((row) => UserModel.fromMap(Map<String, dynamic>.from(row)))
				.toList();
	}

	Future<UserRegistrationResult> registerHrUser({
		required String nombre,
		required String correo,
		required String telefono,
		required String cargo,
		required String rol,
		required String password,
		required String estado,
	}) async {
		final normalizedEmail = correo.trim().toLowerCase();
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
				'role': rol,
				'password': password,
				'status': estado,
			},
		);

		final rawData = response.data;
		if (rawData is! Map || rawData['profile'] is! Map) {
			throw Exception('Supabase no devolvió el perfil creado. Despliega la función create-hr-user.');
		}
		final data = Map<String, dynamic>.from(rawData);
		final user = UserModel.fromMap(
			Map<String, dynamic>.from(data['profile'] as Map),
		);

		return UserRegistrationResult(
			user: user,
			initialPassword: password,
		);
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
}
