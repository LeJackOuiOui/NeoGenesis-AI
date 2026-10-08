import 'package:flutter_test/flutter_test.dart';
import 'package:neogenesis_ai/models/candidate.dart';
import 'package:neogenesis_ai/services/affinity_score_service.dart';

void main() {
  group('AffinityScoreService', () {
    final candidate = Candidate(
      id: 'candidate-1',
      name: 'Juan Pérez',
      cvText: 'Desarrollador Flutter con experiencia en Dart y Firebase.',
      skills: ['Flutter', 'Dart', 'Firebase'],
      experienceYears: 3,
    );

    test('calcula correctamente el puntaje manual', () {
      final score = AffinityScoreService.calculateManualScore(
        candidate: candidate,
        requiredSkills: ['Flutter', 'Dart', 'Firebase'],
        requiredExperienceYears: 2,
      );

      expect(score, 100);
    });

    test('calcula correctamente el puntaje con habilidades parciales', () {
      final score = AffinityScoreService.calculateManualScore(
        candidate: candidate,
        requiredSkills: ['Flutter', 'Dart', 'Firebase', 'SQL'],
        requiredExperienceYears: 2,
      );

      expect(score, 87.5);
    });

    test('ignora mayúsculas y espacios en las habilidades', () {
      final score = AffinityScoreService.calculateManualScore(
        candidate: candidate,
        requiredSkills: [' flutter ', 'DART', ' firebase'],
        requiredExperienceYears: 2,
      );

      expect(score, 100);
    });

    test('calcula correctamente el puntaje final', () {
      final score = AffinityScoreService.calculateFinalScore(
        semanticScore: 80,
        manualScore: 60,
        semanticWeight: 0.7,
        manualWeight: 0.3,
      );

      expect(score, 74);
    });

    test('calcula correctamente la similitud de dos vectores iguales', () {
      final score = AffinityScoreService.calculateCosineSimilarity(
        [1, 0, 0],
        [1, 0, 0],
      );

      expect(score, 100);
    });

    test('devuelve 0 para vectores vacíos', () {
      final score = AffinityScoreService.calculateCosineSimilarity([], []);

      expect(score, 0);
    });

    test('rechaza pesos fuera del rango permitido', () {
      expect(
        () => AffinityScoreService.calculateFinalScore(
          semanticScore: 80,
          manualScore: 60,
          semanticWeight: 1.5,
          manualWeight: -0.5,
        ),
        throwsArgumentError,
      );
    });

    test('rechaza pesos cuya suma no sea 1', () {
      expect(
        () => AffinityScoreService.calculateFinalScore(
          semanticScore: 80,
          manualScore: 60,
          semanticWeight: 0.8,
          manualWeight: 0.3,
        ),
        throwsArgumentError,
      );
    });

    test('ordena los candidatos de mayor a menor puntaje', () {
      final candidate2 = Candidate(
        id: 'candidate-2',
        name: 'María López',
        cvText: 'Desarrolladora Flutter.',
        skills: ['Flutter', 'Dart'],
        experienceYears: 2,
      );

      final results = AffinityScoreService.rankCandidates(
        candidates: [candidate2, candidate],
        semanticScores: {'candidate-1': 90, 'candidate-2': 70},
        requiredSkills: ['Flutter', 'Dart', 'Firebase'],
        requiredExperienceYears: 2,
      );

      expect(results.first.candidate.id, 'candidate-1');
      expect(results.last.candidate.id, 'candidate-2');
    });
  });
}
