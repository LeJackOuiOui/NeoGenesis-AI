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
				.select('id, nombre, correo, cargo, role, estado, created_at')
				.order('created_at', ascending: false);
		return (rows as List)
				.map((row) => UserModel.fromMap(Map<String, dynamic>.from(row)))
				.toList();
	}

	Future<UserRegistrationResult> registerHrUser({
		required String nombre,
		required String correo,
		required String cargo,
		required String rol,
		required String password,
		required String estado,
	}) async {
		final normalizedEmail = correo.trim().toLowerCase();
		final existing = await client
				.from('profiles')
				.select('id')
				.eq('correo', normalizedEmail)
				.maybeSingle();

		if (existing != null) throw const DuplicateUserException();

		final response = await client.functions.invoke(
			'create-hr-user',
			body: {
				'name': nombre.trim(),
				'email': normalizedEmail,
				'position': cargo.trim(),
				'role': rol,
				'password': password,
				'status': estado,
			},
		);

		final data = Map<String, dynamic>.from(response.data as Map);
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
		await client.from('profiles').update({'estado': status}).eq('id', userId);
	}
}
