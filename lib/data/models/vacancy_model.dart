class VacancyModel {
  final String id;
  final String title;
  final double minExperienceYears;
  final List<String> requiredSkills;
  final String minEducationLevel;
  final List<String> removedCandidateIds;

  const VacancyModel({
    required this.id,
    required this.title,
    required this.minExperienceYears,
    required this.requiredSkills,
    required this.minEducationLevel,
    this.removedCandidateIds = const [],
  });

  factory VacancyModel.fromMap(Map<String, dynamic> map) => VacancyModel(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? '',
    minExperienceYears: (map['min_experience_years'] as num?)?.toDouble() ?? 0,
    requiredSkills: map['required_skills'] is List
        ? (map['required_skills'] as List)
              .map((value) => value.toString())
              .toList()
        : const [],
    minEducationLevel: map['min_education_level']?.toString() ?? 'none',
    removedCandidateIds: map['removed_candidate_ids'] is List
        ? (map['removed_candidate_ids'] as List)
              .map((value) => value.toString())
              .toList()
        : const [],
  );

  Map<String, dynamic> toCriteriaMap() => {
    'min_experience_years': minExperienceYears,
    'required_skills': requiredSkills,
    'min_education_level': minEducationLevel,
  };
}

class CandidateEvaluation {
  final String candidateId;
  final bool meetsCriteria;
  final List<String> exclusionReasons;
  final DateTime? evaluatedAt;

  const CandidateEvaluation({
    required this.candidateId,
    required this.meetsCriteria,
    required this.exclusionReasons,
    this.evaluatedAt,
  });

  factory CandidateEvaluation.fromMap(Map<String, dynamic> map) =>
      CandidateEvaluation(
        candidateId: map['candidate_id']?.toString() ?? '',
        meetsCriteria: map['meets_criteria'] == true,
        exclusionReasons: map['exclusion_reasons'] is List
            ? (map['exclusion_reasons'] as List)
                  .map((value) => value.toString())
                  .toList()
            : const [],
        evaluatedAt: DateTime.tryParse(map['evaluated_at']?.toString() ?? ''),
      );
}
