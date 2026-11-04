import 'package:supabase_flutter/supabase_flutter.dart';

class RecruiterAvailabilityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  void _validateBlock({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) {
    final today = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedToday = DateTime(today.year, today.month, today.day);
    if (normalizedDate.isBefore(normalizedToday)) {
      throw ArgumentError('La fecha debe ser hoy o posterior.');
    }
    if (normalizedDate.isAfter(normalizedToday.add(const Duration(days: 60)))) {
      throw ArgumentError('La fecha no puede superar los próximos 60 días.');
    }
    final timePattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?$');
    final startMatch = timePattern.firstMatch(startTime);
    if (startMatch == null) {
      throw ArgumentError('La hora de inicio no tiene un formato válido.');
    }
    final endMatch = timePattern.firstMatch(endTime);
    if (endMatch == null) {
      throw ArgumentError('La hora de fin no tiene un formato válido.');
    }
    int secondsOfDay(RegExpMatch match) =>
        int.parse(match.group(1)!) * 3600 +
        int.parse(match.group(2)!) * 60 +
        int.parse(match.group(3) ?? '0');
    if (secondsOfDay(startMatch) >= secondsOfDay(endMatch)) {
      throw ArgumentError('La hora de fin debe ser posterior a la de inicio.');
    }
  }

  // Insertar bloque
  Future<void> addAvailabilityBlock({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    _validateBlock(date: date, startTime: startTime, endTime: endTime);
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final formattedDate = date.toIso8601String().split('T')[0];

    await _supabase.from('recruiter_availability').insert({
      'recruiter_id': user.id,
      'date': formattedDate,
      'start_time': startTime,
      'end_time': endTime,
      'is_booked': false,
    });
  }

  // Obtener bloques del reclutador (y opcionalmente limpiar los vencidos)
  Future<List<Map<String, dynamic>>> getMyAvailability() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Opcional: Eliminar automáticamente los bloques cuya fecha ya pasó y no fueron reservados
    await _supabase
        .from('recruiter_availability')
        .delete()
        .eq('recruiter_id', user.id)
        .eq('is_booked', false)
        .lt('date', today);

    // Obtener los vigentes
    final response = await _supabase
        .from('recruiter_availability')
        .select()
        .eq('recruiter_id', user.id)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // Actualizar un bloque existente
  Future<void> updateAvailabilityBlock({
    required String id,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    _validateBlock(date: date, startTime: startTime, endTime: endTime);
    final formattedDate = date.toIso8601String().split('T')[0];
    await _supabase
        .from('recruiter_availability')
        .update({
          'date': formattedDate,
          'start_time': startTime,
          'end_time': endTime,
        })
        .eq('id', id);
  }

  // Eliminar un bloque
  Future<void> deleteAvailabilityBlock(String id) async {
    await _supabase.from('recruiter_availability').delete().eq('id', id);
  }
}
