class UserModel {
  final String? id;
  final String nombre;
  final String correo;
  final String cargo;
  final String rol;
  final String estado;
  final double salarioBase;
  final String tipoContrato;
  final DateTime? fechaIngreso;
  final bool bajaLogica;
  final DateTime? creadoEn;
  final String? companyNit;
  final String? companyRut;
  final String? companyAddress;
  final String? companyVerificationStatus;
  final String? telefono;
  final String? companyDv;
  final bool? isRRHH;

  const UserModel({
    this.id,
    required this.nombre,
    required this.correo,
    required this.cargo,
    required this.rol,
    required this.estado,
    this.salarioBase = 0,
    this.tipoContrato = 'Tiempo Completo',
    this.fechaIngreso,
    this.bajaLogica = false,
    this.creadoEn,
    this.companyNit,
    this.companyRut,
    this.companyAddress,
    this.companyVerificationStatus,
    this.telefono,
    this.companyDv,
    this.isRRHH,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final estado = (map['estado'] ?? 'Activo').toString();
    final bajaLogica =
        map['baja_logica'] == true ||
        map['bajaLogica'] == true ||
        estado.toLowerCase() == 'inactivo';

    return UserModel(
      id: map['id']?.toString(),
      nombre: map['nombre'] as String? ?? '',
      correo: (map['email'] ?? map['correo']) as String? ?? '',
      cargo: map['cargo'] as String? ?? '',
      rol: (map['role'] ?? map['rol']) as String? ?? 'Empleado',
      estado: estado,
      salarioBase: _parseDouble(map['salario_base'] ?? map['salarioBase']),
      tipoContrato:
          (map['tipo_contrato'] ?? map['tipoContrato'] ?? 'Tiempo Completo')
              .toString(),
      fechaIngreso: DateTime.tryParse(
        (map['fecha_ingreso'] ?? map['fechaIngreso'] ?? '').toString(),
      ),
      bajaLogica: bajaLogica,
      creadoEn: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      companyNit: map['company_nit']?.toString(),
      companyRut: map['company_rut']?.toString(),
      companyAddress: map['company_address']?.toString(),
      companyVerificationStatus: map['company_verification_status']?.toString(),
      telefono: map['telefono']?.toString(),
      companyDv: map['company_dv']?.toString(),
      isRRHH: map['is_rrhh'] == true || map['isRRHH'] == true,
    );
  }
}
