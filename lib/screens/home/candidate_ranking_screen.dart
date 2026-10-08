import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/candidate_match.dart';
import '../../models/job.dart';
import '../../services/affinity_score_service.dart';
import '../../services/embedding_service.dart';
import '../../services/mock_embedding_service.dart';

class CandidateRankingScreen extends StatefulWidget {
  final List<Candidate> candidates;
  final Job job;
  final EmbeddingService? embeddingService;

  const CandidateRankingScreen({
    super.key,
    required this.candidates,
    required this.job,
    this.embeddingService,
  });

  @override
  State<CandidateRankingScreen> createState() => _CandidateRankingScreenState();
}

class _CandidateRankingScreenState extends State<CandidateRankingScreen> {
  late final EmbeddingService _embeddingService;

  bool _loading = false;
  List<CandidateMatch> _results = [];

  double _semanticWeight = 0.7;
  double _manualWeight = 0.3;

  late final List<Candidate> _candidates;

  late final Job _job;

  @override
  void initState() {
    super.initState();

    _candidates = widget.candidates;
    _job = widget.job;

    _embeddingService = widget.embeddingService ?? MockEmbeddingService();
  }

  Future<void> _calculateRanking() async {
    setState(() {
      _loading = true;
    });

    final semanticScores = await AffinityScoreService.calculateSemanticScores(
      jobDescription: _job.description,
      candidates: _candidates,
      embeddingService: _embeddingService,
    );

    final results = AffinityScoreService.rankCandidates(
      candidates: _candidates,
      semanticScores: semanticScores,
      requiredSkills: _job.requiredSkills,
      requiredExperienceYears: _job.requiredExperienceYears,
      semanticWeight: _semanticWeight,
      manualWeight: _manualWeight,
    );

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking de candidatos')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_job.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_job.description),
            const SizedBox(height: 24),

            Text(
              'Peso de la afinidad semántica: '
              '${(_semanticWeight * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            Slider(
              value: _semanticWeight,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(_semanticWeight * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _semanticWeight = value;
                  _manualWeight = 1 - value;
                });
              },
            ),

            Text(
              'Peso de experiencia y habilidades: '
              '${(_manualWeight * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _loading ? null : _calculateRanking,
              child: Text(_loading ? 'Calculando...' : 'Calcular afinidad'),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        'Pulsa "Calcular afinidad" '
                        'para generar el ranking.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(result.candidate.name),
                            subtitle: Text(
                              'Semántico: '
                              '${result.semanticScore.toStringAsFixed(1)}\n'
                              'Manual: '
                              '${result.manualScore.toStringAsFixed(1)}',
                            ),
                            trailing: Text(
                              result.finalScore.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
