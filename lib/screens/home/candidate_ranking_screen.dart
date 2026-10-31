import 'package:flutter/material.dart';

import '../../data/models/candidate.dart';
import '../../data/models/candidate_match.dart';
import '../../data/models/job.dart';
import '../../data/services/affinity_score_service.dart';
import 'candidate_selection_screen.dart';

class CandidateRankingScreen extends StatefulWidget {
  final String vacancyId;
  final List<Candidate> candidates;
  final Job job;

  const CandidateRankingScreen({
    super.key,
    required this.candidates,
    required this.job,
    required this.vacancyId,
  });

  @override
  State<CandidateRankingScreen> createState() => _CandidateRankingScreenState();
}

class _CandidateRankingScreenState extends State<CandidateRankingScreen> {
  bool _loading = false;
  List<CandidateMatch> _results = [];
  String? _error;

  late final List<Candidate> _candidates;
  late final Job _job;

  @override
  void initState() {
    super.initState();

    _candidates = widget.candidates;
    _job = widget.job;
  }

  Future<void> _calculateRanking() async {
    if (_candidates.isEmpty) {
      setState(() {
        _error = 'No hay candidatos disponibles para generar el ranking.';
        _results = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = AffinityScoreService.rankCandidates(
        candidates: _candidates,
        semanticScores: {},
        requiredSkills: _job.requiredSkills,
        requiredExperienceYears: _job.requiredExperienceYears,
        semanticWeight: 0,
        manualWeight: 1,
      );

      if (!mounted) return;

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'No fue posible generar el ranking: $e';
        _loading = false;
      });
    }
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
            const SizedBox(height: 20),

            const Text(
              'El puntaje se calcula con base en la experiencia '
              'y las habilidades de cada candidato.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Experiencia: 50 puntos. Habilidades: 50 puntos.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _calculateRanking,
                icon: const Icon(Icons.leaderboard),
                label: Text(_loading ? 'Calculando...' : 'Calcular ranking'),
              ),
            ),

            const SizedBox(height: 20),

            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CandidateSelectionScreen(
                            rankedCandidates: _results.take(2).toList(),
                            availableCandidates: _candidates,
                            vacancyId: widget.vacancyId,
                          ),
                        ),
                      );
                    },
                    child: const Text('Revisar selección'),
                  ),
                ),
              ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _results.isEmpty
                  ? const Center(
                      child: Text(
                        'Pulsa "Calcular ranking" '
                        'para generar el ranking.',
                        textAlign: TextAlign.center,
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
                              'Experiencia y habilidades: '
                              '${result.manualScore.toStringAsFixed(1)} / 100',
                            ),
                            trailing: Text(
                              '${result.finalScore.toStringAsFixed(1)}%',
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
