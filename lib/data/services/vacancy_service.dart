import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/candidate_model.dart';
import '../models/vacancy_model.dart';
import 'candidate_criteria_evaluator.dart';

class VacancyService {
  final SupabaseClient client;

  const VacancyService(this.client);

  Future<List<VacancyModel>> fetchVacancies() async {
    final currentUser = client.auth.currentUser;
    final metadata = currentUser?.userMetadata;
    final isRRHH =
        metadata?['isRRHH'] == true ||
        metadata?['role']?.toString().toLowerCase() == 'responsable rrhh';

    // 1. Consultamos las vacantes normalmente sin joins forzados
    var query = client
        .from('vacantes')
        .select(
          'id, title, min_experience_years, required_skills, min_education_level, removed_candidate_ids, created_by',
        );

    // Si es una empresa, mostramos únicamente sus vacantes creadas
    if (isRRHH && currentUser != null) {
      query = query.eq('created_by', currentUser.id);
    }

    final rows = await query.order('created_at', ascending: false);
    final vacanciesList = (rows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    // 2. Obtenemos los IDs de las empresas creadoras para buscar sus estados de verificación
    final creatorIds = vacanciesList
        .map((v) => v['created_by']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .toList();

    Map<String, String> verificationStatuses = {};
    if (creatorIds.isNotEmpty) {
      final profilesResponse = await client
          .from('profiles')
          .select('id, company_verification_status')
          .inFilter('id', creatorIds);

      for (var p in (profilesResponse as List)) {
        final profileMap = Map<String, dynamic>.from(p);
        verificationStatuses[profileMap['id'].toString()] =
            profileMap['company_verification_status']?.toString() ?? 'pending';
      }
    }

    // 3. Inyectamos el estado de verificación en cada vacante para el modelo
    return vacanciesList.map((data) {
      final creatorId = data['created_by']?.toString();
      data['company_verification_status'] =
          verificationStatuses[creatorId] ?? 'pending';
      return VacancyModel.fromMap(data);
    }).toList();
  }

  Future<void> aplicarAVacante(String vacancyId) async {
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      throw Exception('Debes iniciar sesión para postularte.');
    }

    // Verificamos que el usuario tenga su hoja de vida registrada.
    final candidate = await client
        .from('candidatos')
        .select('id')
        .eq('created_by', currentUser.id)
        .maybeSingle();

    if (candidate == null) {
      throw Exception(
        'Primero debes completar y guardar tu hoja de vida para postularte.',
      );
    }

    // Verificamos que no exista una postulación anterior.
    final existingApplication = await client
        .from('postulaciones')
        .select('id')
        .eq('vacante_id', vacancyId)
        .eq('usuario_id', currentUser.id)
        .maybeSingle();

    if (existingApplication != null) {
      throw Exception('Ya te has postulado a esta vacante.');
    }

    await client.from('postulaciones').insert({
      'vacante_id': vacancyId,
      'usuario_id': currentUser.id,
      'estado': 'enviada',
    });
  }

  Future<VacancyModel> saveVacancy({
    String? id,
    required String title,
    required double minExperienceYears,
    required List<String> requiredSkills,
    required String minEducationLevel,
  }) async {
    final currentUser = client.auth.currentUser;
    final vacancyId = id ?? _newVacancyId();
    final payload = {
      'id': vacancyId,
      'title': title.trim(),
      'min_experience_years': minExperienceYears,
      'required_skills': requiredSkills,
      'min_education_level': minEducationLevel,
      if (id == null && currentUser != null) 'created_by': currentUser.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = id == null
        ? await client.from('vacantes').insert(payload).select().single()
        : await client
              .from('vacantes')
              .update(payload)
              .eq('id', vacancyId)
              .select()
              .single();
    return VacancyModel.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteVacancy(String vacancyId) async {
    final deleted = await client
        .from('vacantes')
        .delete()
        .eq('id', vacancyId)
        .select('id')
        .maybeSingle();
    if (deleted == null) {
      throw Exception(
        'No se pudo eliminar la vacante. Verifica tus permisos de reclutador.',
      );
    }
  }

  Future<void> removeCandidateFromVacancy({
    required String vacancyId,
    required String candidateId,
  }) async {
    final row = await client
        .from('vacantes')
        .select('removed_candidate_ids, evaluations')
        .eq('id', vacancyId)
        .maybeSingle();
    if (row == null) throw Exception('No se encontró la vacante.');

    final removedIds = row['removed_candidate_ids'] is List
        ? (row['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : <String>{};
    removedIds.add(candidateId);
    final evaluations = row['evaluations'] is Map
        ? Map<String, dynamic>.from(row['evaluations'] as Map)
        : <String, dynamic>{};
    evaluations.remove(candidateId);

    await client
        .from('vacantes')
        .update({
          'removed_candidate_ids': removedIds.toList(),
          'evaluations': evaluations,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vacancyId);
  }

  Future<void> restoreCandidateToVacancy({
    required String vacancyId,
    required String candidateId,
  }) async {
    final row = await client
        .from('vacantes')
        .select('removed_candidate_ids')
        .eq('id', vacancyId)
        .maybeSingle();
    if (row == null) throw Exception('No se encontró la vacante.');

    final removedIds = row['removed_candidate_ids'] is List
        ? (row['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : <String>{};
    removedIds.remove(candidateId);
    await client
        .from('vacantes')
        .update({
          'removed_candidate_ids': removedIds.toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', vacancyId);
  }

  String _newVacancyId() {
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<Map<String, CandidateEvaluation>> evaluateCandidates({
    required VacancyModel vacancy,
    required List<CandidateModel> candidates,
  }) async {
    final vacancyRow = await client
        .from('vacantes')
        .select('removed_candidate_ids')
        .eq('id', vacancy.id)
        .maybeSingle();
    final removedIds = vacancyRow?['removed_candidate_ids'] is List
        ? (vacancyRow!['removed_candidate_ids'] as List)
              .map((id) => id.toString())
              .toSet()
        : vacancy.removedCandidateIds.toSet();
    final evaluatedAt = DateTime.now().toUtc();
    final evaluations = <String, CandidateEvaluation>{};
    for (final candidate in candidates) {
      if (removedIds.contains(candidate.id)) continue;
      final reasons = CandidateCriteriaEvaluator.exclusionReasonsFor(
        candidate,
        vacancy,
      );
      evaluations[candidate.id] = CandidateEvaluation(
        candidateId: candidate.id,
        meetsCriteria: reasons.isEmpty,
        exclusionReasons: reasons,
        evaluatedAt: evaluatedAt,
      );
    }

    final evaluationData = {
      for (final entry in evaluations.entries)
        entry.key: {
          'meets_criteria': entry.value.meetsCriteria,
          'exclusion_reasons': entry.value.exclusionReasons,
          'evaluated_at': evaluatedAt.toIso8601String(),
        },
    };
    await client
        .from('vacantes')
        .update({
          'evaluations': evaluationData,
          'updated_at': evaluatedAt.toIso8601String(),
        })
        .eq('id', vacancy.id);

    return evaluations;
  }

  Future<Map<String, CandidateEvaluation>> fetchEvaluations(
    String vacancyId,
  ) async {
    final row = await client
        .from('vacantes')
        .select('evaluations')
        .eq('id', vacancyId)
        .maybeSingle();
    final rawEvaluations = row?['evaluations'];
    if (rawEvaluations is! Map) return const {};
    return {
      for (final entry in rawEvaluations.entries)
        entry.key.toString(): CandidateEvaluation.fromMap({
          ...Map<String, dynamic>.from(entry.value as Map),
          'candidate_id': entry.key.toString(),
        }),
    };
  }

  Future<bool> usuarioYaSePostulo(String vacanteId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await client
        .from('postulaciones')
        .select('id')
        .eq('vacante_id', vacanteId)
        .eq('usuario_id', userId)
        .maybeSingle();

    return response != null;
  }

  Future<void> cancelarPostulacion(String vacanteId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    await client
        .from('postulaciones')
        .delete()
        .eq('vacante_id', vacanteId)
        .eq('usuario_id', userId);
  }

  Future<Map<String, int>> fetchConteoPostulaciones() async {
    try {
      final response = await client.from('postulaciones').select('vacante_id');
      final Map<String, int> conteo = {};
      for (var row in (response as List)) {
        final vacanteId = row['vacante_id'].toString();
        conteo[vacanteId] = (conteo[vacanteId] ?? 0) + 1;
      }
      return conteo;
    } catch (_) {
      return {};
    }
  }

  Future<void> actualizarEstadoPostulacion(
    String postulacionId,
    String nuevoEstado,
  ) async {
    final response = await client
        .from('postulaciones')
        .update({'estado': nuevoEstado})
        .eq('id', postulacionId)
        .select('id')
        .maybeSingle();

    if (response == null) {
      throw Exception('No se pudo actualizar el estado de la postulación.');
    }
  }

  /// Obtiene los candidatos postulados a una vacante específica.
  Future<List<Map<String, dynamic>>> fetchCandidatesWithPostulationId(
    String vacancyId,
  ) async {
    final postResponse = await client
        .from('postulaciones')
        .select('id, usuario_id, estado')
        .eq('vacante_id', vacancyId);

    if ((postResponse as List).isEmpty) return [];

    final Map<String, Map<String, String>> userInfoMap = {};

    for (var row in postResponse) {
      final userId = row['usuario_id']?.toString();
      final postId = row['id']?.toString();
      final estado = row['estado']?.toString() ?? 'enviada';

      if (userId != null && postId != null) {
        userInfoMap[userId] = {'postulacion_id': postId, 'estado': estado};
      }
    }

    final userIds = userInfoMap.keys.toList();
    if (userIds.isEmpty) return [];

    final candidatesResponse = await client
        .from('candidatos')
        .select('id, full_name, email, phone, resume_data, created_by')
        .inFilter('created_by', userIds);

    List<Map<String, dynamic>> result = [];

    for (var row in (candidatesResponse as List)) {
      final candidateMap = Map<String, dynamic>.from(row as Map);
      final createdBy = candidateMap['created_by']?.toString();

      if (createdBy != null && userInfoMap.containsKey(createdBy)) {
        candidateMap['postulacion_id'] =
            userInfoMap[createdBy]!['postulacion_id'];
        candidateMap['estado_postulacion'] = userInfoMap[createdBy]!['estado'];
        result.add(candidateMap);
      }
    }

    return result;
  }
}
