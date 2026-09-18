class UserModel {
	final String? id;
	final String nombre;
	final String correo;
	final String cargo;
	final String rol;
	final String estado;
	final DateTime? creadoEn;

	const UserModel({
		this.id,
		required this.nombre,
		required this.correo,
		required this.cargo,
		required this.rol,
		required this.estado,
		this.creadoEn,
	});

	factory UserModel.fromMap(Map<String, dynamic> map) {
		return UserModel(
			id: map['id']?.toString(),
			nombre: map['nombre'] as String? ?? '',
			correo: (map['email'] ?? map['correo']) as String? ?? '',
			cargo: map['cargo'] as String? ?? '',
			rol: (map['role'] ?? map['rol']) as String? ?? 'Empleado',
			estado: map['estado'] as String? ?? 'Activo',
			creadoEn: DateTime.tryParse(map['created_at']?.toString() ?? ''),
		);
	}
}
