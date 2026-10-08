import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/data/models/candidate_model.dart';
import 'package:neogenesis_ai/data/models/vacancy_model.dart';
import 'package:neogenesis_ai/data/services/candidate_criteria_evaluator.dart';

void main() {
  group('CandidateCriteriaEvaluator', () {
    test('acepta cuando cumple experiencia, habilidades y formación', () {
      final candidate = _candidate({
        'skills': ['Dart / Flutter', 'SQL'],
        'experience': [
          {'start_date': '2022-01', 'end_date': '2023-12'},
        ],
        'education': [
          {'degree': 'Bachelor of Science', 'field': 'Computer Science'},
        ],
      });
      final vacancy = _vacancy(
        minExperienceYears: 1.5,
        requiredSkills: ['Dart', 'SQL'],
        minEducationLevel: 'bachelor',
      );

      expect(
        CandidateCriteriaEvaluator.exclusionReasonsFor(candidate, vacancy),
        isEmpty,
      );
    });

    test('registra un motivo por cada criterio incumplido', () {
      final candidate = _candidate(const {});
      final vacancy = _vacancy(
        minExperienceYears: 3,
        requiredSkills: ['Python', 'PostgreSQL'],
        minEducationLevel: 'doctorate',
      );

      final reasons = CandidateCriteriaEvaluator.exclusionReasonsFor(
        candidate,
        vacancy,
      );

      expect(reasons, hasLength(3));
      expect(reasons[0], contains('Experiencia'));
      expect(reasons[1], contains('Python'));
      expect(reasons[1], contains('PostgreSQL'));
      expect(reasons[2], contains('Formación'));
    });

    test('no duplica experiencia laboral que se traslapa', () {
      final candidate = _candidate({
        'experience': [
          {'start_date': '2020-01', 'end_date': '2020-12'},
          {'start_date': '2020-06', 'end_date': '2021-06'},
        ],
      });

      expect(
        CandidateCriteriaEvaluator.exclusionReasonsFor(
          candidate,
          _vacancy(minExperienceYears: 1.5),
        ),
        isEmpty,
      );
    });

    test('no interpreta una fecha final vacía como empleo actual', () {
      final candidate = _candidate({
        'experience': [
          {'start_date': '2020-01', 'end_date': ''},
        ],
      });

      final reasons = CandidateCriteriaEvaluator.exclusionReasonsFor(
        candidate,
        _vacancy(minExperienceYears: 1),
      );

      expect(reasons, hasLength(1));
      expect(reasons.single, contains('Experiencia'));
    });

    test('admite fechas de mes en español y formato mes/año', () {
      final candidate = _candidate({
        'experience': [
          {'start_date': 'ene 2020', 'end_date': '12/2021'},
        ],
      });

      expect(
        CandidateCriteriaEvaluator.exclusionReasonsFor(
          candidate,
          _vacancy(minExperienceYears: 2),
        ),
        isEmpty,
      );
    });
  });
}

CandidateModel _candidate(Map<String, dynamic> resumeData) => CandidateModel(
  id: 'candidate-1',
  fullName: 'Alex Rivera',
  email: 'alex@example.com',
  phone: '',
  resumeData: resumeData,
);

VacancyModel _vacancy({
  double minExperienceYears = 0,
  List<String> requiredSkills = const [],
  String minEducationLevel = 'none',
}) => VacancyModel(
  id: 'vacancy-1',
  title: 'Vacante de prueba',
  minExperienceYears: minExperienceYears,
  requiredSkills: requiredSkills,
  minEducationLevel: minEducationLevel,
);
