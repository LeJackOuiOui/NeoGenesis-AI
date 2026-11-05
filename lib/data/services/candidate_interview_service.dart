import 'package:supabase_flutter/supabase_flutter.dart';

class CandidateInterviewService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getAvailableSlotsForVacancy(
    String vacancyId,
  ) async {
    final vacancyRes = await _supabase
        .from('vacantes')
        .select('created_by')
        .eq('id', vacancyId)
        .single();

    final recruiterId = vacancyRes['created_by'];

    final slots = await _supabase
        .from('recruiter_availability')
        .select()
        .eq('recruiter_id', recruiterId)
        .eq('is_booked', false)
        .order('date', ascending: true);

    return List<Map<String, dynamic>>.from(slots);
  }

  Future<void> bookInterview({
    required String vacancyId,
    required String candidateId,
    required String recruiterId,
    required String availabilityId,
    required DateTime scheduledDateTime,
  }) async {
    // Reservar el bloque solamente si todavía está libre.
    final reserved = await _supabase
        .from('recruiter_availability')
        .update({'is_booked': true})
        .eq('id', availabilityId)
        .eq('recruiter_id', recruiterId)
        .eq('is_booked', false)
        .select('id');

    if (reserved.isEmpty) {
      throw Exception('Este horario ya fue reservado. Selecciona otro.');
    }

    try {
      // Registrar la entrevista.
      await _supabase.from('interviews').insert({
        'vacancy_id': vacancyId,
        'candidate_id': candidateId,
        'recruiter_id': recruiterId,
        'availability_id': availabilityId,
        'scheduled_at': scheduledDateTime.toIso8601String(),
        'status': 'scheduled',
      });
    } catch (e) {
      // Liberar el horario si falla el registro.
      await _supabase
          .from('recruiter_availability')
          .update({'is_booked': false})
          .eq('id', availabilityId);

      rethrow;
    }
  }
}
