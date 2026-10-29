import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/candidate_model.dart';
import '../models/candidate_report_item.dart';
import '../models/vacancy_model.dart';
import 'candidate_criteria_evaluator.dart';

class CandidateReportService {
  final SupabaseClient client;

  const CandidateReportService(this.client);

  Future<List<CandidateReportItem>> fetchReport({
    String? vacancyId,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = client
        .from('postulaciones')
        .select('id, vacante_id, usuario_id, estado');
    if (vacancyId != null) query = query.eq('vacante_id', vacancyId);
    if (status != null) query = query.eq('estado', status);

    final rows = await query as List;
    if (rows.isEmpty) return const [];

    final applications = rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final userIds = applications
        .map((row) => row['usuario_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final vacancyIds = applications
        .map((row) => row['vacante_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final candidatesByUser = <String, CandidateModel>{};
    final candidateRegisteredAtByUser = <String, DateTime?>{};
    if (userIds.isNotEmpty) {
      final results = await Future.wait([
        client
            .from('profiles')
            .select('id, nombre, email, telefono, created_at')
            .inFilter('id', userIds),
        client
            .from('candidatos')
            .select(
              'id, full_name, email, phone, resume_data, created_by, created_at',
            )
            .inFilter('created_by', userIds)
            .order('created_at', ascending: false),
        client
            .from('candidatos')
            .select(
              'id, full_name, email, phone, resume_data, created_by, created_at',
            )
            .inFilter('id', userIds),
      ]);

      for (final row in results[0] as List) {
        final profile = Map<String, dynamic>.from(row as Map);
        final userId = profile['id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        candidatesByUser[userId] = CandidateModel.fromMap({
          'id': userId,
          'full_name': profile['nombre'],
          'email': profile['email'],
          'phone': profile['telefono'],
          'resume_data': const <String, dynamic>{},
        });
        candidateRegisteredAtByUser[userId] = DateTime.tryParse(
          profile['created_at']?.toString() ?? '',
        );
      }

      final candidateRows = [...(results[1] as List), ...(results[2] as List)];
      for (final row in candidateRows) {
        final candidateData = Map<String, dynamic>.from(row as Map);
        final userId = candidateData['created_by']?.toString();
        final matchingUserId = userIds.contains(userId)
            ? userId
            : userIds.contains(candidateData['id']?.toString())
            ? candidateData['id']?.toString()
            : null;
        if (matchingUserId != null && matchingUserId.isNotEmpty) {
          final profile = candidatesByUser[matchingUserId];
          final resumeCandidate = CandidateModel.fromMap(candidateData);
          candidatesByUser[matchingUserId] = CandidateModel(
            id: resumeCandidate.id,
            fullName: profile?.fullName.trim().isNotEmpty == true
                ? profile!.fullName
                : resumeCandidate.fullName,
            email: profile?.email.trim().isNotEmpty == true
                ? profile!.email
                : resumeCandidate.email,
            phone: profile?.phone?.trim().isNotEmpty == true
                ? profile!.phone
                : resumeCandidate.phone,
            resumeData: resumeCandidate.resumeData,
            profilePosition: profile?.profilePosition,
          );
          if (candidateRegisteredAtByUser[matchingUserId] == null) {
            candidateRegisteredAtByUser[matchingUserId] = DateTime.tryParse(
              candidateData['created_at']?.toString() ?? '',
            );
          }
        }
      }
    }

    final vacanciesById = <String, VacancyModel>{};
    if (vacancyIds.isNotEmpty) {
      final vacancyRows = await client
          .from('vacantes')
          .select(
            'id, title, min_experience_years, required_skills, min_education_level',
          )
          .inFilter('id', vacancyIds);
      for (final row in vacancyRows as List) {
        final vacancy = VacancyModel.fromMap(Map<String, dynamic>.from(row));
        vacanciesById[vacancy.id] = vacancy;
      }
    }

    final report = applications.map((application) {
      final userId = application['usuario_id']?.toString() ?? '';
      final currentVacancyId = application['vacante_id']?.toString() ?? '';
      final candidate = candidatesByUser[userId];
      final vacancy = vacanciesById[currentVacancyId];
      final candidateRegisteredAt = candidateRegisteredAtByUser[userId];
      return CandidateReportItem(
        vacancyId: currentVacancyId,
        vacancyTitle: vacancy?.title ?? 'Vacante no disponible',
        candidate: candidate,
        status: application['estado']?.toString() ?? 'sin estado',
        candidateRegisteredAt: candidateRegisteredAt,
        score: candidate == null || vacancy == null
            ? null
            : CandidateCriteriaEvaluator.scoreFor(candidate, vacancy),
      );
    }).toList();

    return report.where((item) {
      final registeredAt = item.candidateRegisteredAt?.toLocal();
      if (registeredAt == null) return from == null && to == null;
      final registeredDate = DateTime(
        registeredAt.year,
        registeredAt.month,
        registeredAt.day,
      );
      if (from != null &&
          registeredDate.isBefore(DateTime(from.year, from.month, from.day))) {
        return false;
      }
      if (to != null &&
          registeredDate.isAfter(DateTime(to.year, to.month, to.day))) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) {
      final dateA = a.candidateRegisteredAt;
      final dateB = b.candidateRegisteredAt;
      if (dateA == null) return dateB == null ? 0 : 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
  }
}
