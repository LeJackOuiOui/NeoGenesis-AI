import 'dart:math';

import '../models/candidate.dart';
import '../models/candidate_match.dart';
import 'embedding_service.dart';

class AffinityScoreService {
  /// Calcula el puntaje manual del candidato.
  ///
  /// Experiencia: máximo 50 puntos.
  /// Habilidades: máximo 50 puntos.
  ///
  /// Resultado: 0 - 100.
  static double calculateManualScore({
    required Candidate candidate,
    required List<String> requiredSkills,
    required double requiredExperienceYears,
  }) {
    // -----------------------------
    // Puntaje de experiencia
    // -----------------------------
    double experienceScore = 0;

    if (requiredExperienceYears > 0) {
      experienceScore =
          (candidate.experienceYears / requiredExperienceYears) * 50;

      experienceScore = min(experienceScore, 50);
    } else {
      experienceScore = 50;
    }

    // -----------------------------
    // Puntaje de habilidades
    // -----------------------------
    double skillsScore = 0;

    if (requiredSkills.isNotEmpty) {
      final candidateSkills = candidate.skills
          .map((skill) => skill.trim().toLowerCase())
          .toSet();

      final normalizedRequiredSkills = requiredSkills
          .map((skill) => skill.trim().toLowerCase())
          .toSet();

      final matchingSkills = normalizedRequiredSkills
          .where(candidateSkills.contains)
          .length;

      skillsScore =
          (matchingSkills / normalizedRequiredSkills.length) * 50;
    } else {
      skillsScore = 50;
    }

    return experienceScore + skillsScore;
  }

  /// Combina el puntaje semántico y el puntaje manual.
  ///
  /// Ambos pesos deben estar entre 0 y 1
  /// y su suma debe ser igual a 1.
  static double calculateFinalScore({
    required double semanticScore,
    required double manualScore,
    double semanticWeight = 0.7,
    double manualWeight = 0.3,
  }) {
    _validateWeights(
      semanticWeight: semanticWeight,
      manualWeight: manualWeight,
    );

    return (semanticScore * semanticWeight) +
        (manualScore * manualWeight);
  }

  /// Valida los pesos utilizados para calcular el puntaje final.
  static void _validateWeights({
    required double semanticWeight,
    required double manualWeight,
  }) {
    if (semanticWeight < 0 ||
        semanticWeight > 1 ||
        manualWeight < 0 ||
        manualWeight > 1) {
      throw ArgumentError(
        'Los pesos deben estar entre 0 y 1.',
      );
    }

    const tolerance = 0.0001;

    if ((semanticWeight + manualWeight - 1).abs() > tolerance) {
      throw ArgumentError(
        'La suma de los pesos debe ser igual a 1.',
      );
    }
  }

  /// Calcula la similitud coseno entre dos embeddings.
  ///
  /// El resultado se normaliza de 0 a 100.
  static double calculateCosineSimilarity(
    List<double> vectorA,
    List<double> vectorB,
  ) {
    if (vectorA.isEmpty || vectorB.isEmpty) {
      return 0;
    }

    if (vectorA.length != vectorB.length) {
      throw ArgumentError(
        'Los embeddings deben tener la misma cantidad de dimensiones.',
      );
    }

    double dotProduct = 0;
    double magnitudeA = 0;
    double magnitudeB = 0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      magnitudeA += vectorA[i] * vectorA[i];
      magnitudeB += vectorB[i] * vectorB[i];
    }

    if (magnitudeA == 0 || magnitudeB == 0) {
      return 0;
    }

    final cosine =
        dotProduct / (sqrt(magnitudeA) * sqrt(magnitudeB));

    // Convierte [-1, 1] a [0, 100].
    final normalizedScore = ((cosine + 1) / 2) * 100;

    return normalizedScore.clamp(0, 100);
  }

  /// Calcula el ranking completo de candidatos.
  ///
  /// Los candidatos se ordenan de mayor a menor puntaje final.
  static List<CandidateMatch> rankCandidates({
    required List<Candidate> candidates,
    required Map<String, double> semanticScores,
    required List<String> requiredSkills,
    required double requiredExperienceYears,
    double semanticWeight = 0.7,
    double manualWeight = 0.3,
  }) {
    _validateWeights(
      semanticWeight: semanticWeight,
      manualWeight: manualWeight,
    );

    final results = candidates.map((candidate) {
      final semanticScore = semanticScores[candidate.id] ?? 0;

      final manualScore = calculateManualScore(
        candidate: candidate,
        requiredSkills: requiredSkills,
        requiredExperienceYears: requiredExperienceYears,
      );

      final finalScore = calculateFinalScore(
        semanticScore: semanticScore,
        manualScore: manualScore,
        semanticWeight: semanticWeight,
        manualWeight: manualWeight,
      );

      return CandidateMatch(
        candidate: candidate,
        semanticScore: semanticScore,
        manualScore: manualScore,
        finalScore: finalScore,
      );
    }).toList();

    results.sort(
      (a, b) => b.finalScore.compareTo(a.finalScore),
    );

    return results;
  }

  /// Genera los embeddings de la vacante y de cada candidato.
  ///
  /// Después calcula la similitud semántica entre ellos.
  static Future<Map<String, double>> calculateSemanticScores({
    required String jobDescription,
    required List<Candidate> candidates,
    required EmbeddingService embeddingService,
  }) async {
    final jobEmbedding =
        await embeddingService.generateEmbedding(jobDescription);

    final semanticScores = <String, double>{};

    for (final candidate in candidates) {
      final candidateEmbedding =
          await embeddingService.generateEmbedding(
        candidate.cvText,
      );

      final score = calculateCosineSimilarity(
        jobEmbedding,
        candidateEmbedding,
      );

      semanticScores[candidate.id] = score;
    }

    return semanticScores;
  }
}