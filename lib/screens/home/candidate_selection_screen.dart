import 'package:flutter/material.dart';

import '../../models/candidate.dart';
import '../../models/candidate_match.dart';
import '../../models/candidate_selection.dart';
import '../../services/candidate_selection_service.dart';

class CandidateSelectionScreen extends StatefulWidget {
  final List<CandidateMatch> rankedCandidates;
  final List<Candidate> availableCandidates;

  const CandidateSelectionScreen({
    super.key,
    required this.rankedCandidates,
    required this.availableCandidates,
  });

  @override
  State<CandidateSelectionScreen> createState() =>
      _CandidateSelectionScreenState();
}

class _CandidateSelectionScreenState extends State<CandidateSelectionScreen> {
  late final List<CandidateSelection> _selections;

  @override
  void initState() {
    super.initState();

    _selections = CandidateSelectionService.createSelection(
      widget.rankedCandidates.map((match) => match.candidate).toList(),
    );
  }

  void _confirmSelection() {
    setState(() {
      CandidateSelectionService.confirmSelection(_selections);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Selección confirmada correctamente.')),
    );
  }

  void _addCandidateManually() {
    final selectedIds = _selections
        .map((selection) => selection.candidate.id)
        .toSet();

    final available = widget.availableCandidates
        .where((candidate) => !selectedIds.contains(candidate.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay candidatos disponibles para agregar.'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar candidato'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, index) {
                final candidate = available[index];

                return ListTile(
                  title: Text(candidate.name),
                  subtitle: Text(
                    '${candidate.experienceYears} años de experiencia',
                  ),
                  onTap: () {
                    setState(() {
                      _selections.add(
                        CandidateSelection(
                          candidate: candidate,
                          selected: true,
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankedIds = widget.rankedCandidates
        .map((match) => match.candidate.id)
        .toSet();

    final manualSelections = _selections
        .where((selection) => !rankedIds.contains(selection.candidate.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmación de candidatos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addCandidateManually,
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar candidato manualmente'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Candidatos del ranking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...widget.rankedCandidates.asMap().entries.map((entry) {
                  final index = entry.key;
                  final match = entry.value;

                  final selection = _selections.firstWhere(
                    (item) => item.candidate.id == match.candidate.id,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(match.candidate.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Score final: '
                            '${match.finalScore.toStringAsFixed(1)}',
                          ),
                          if (selection.interviewEligible)
                            const Text(
                              'Apto para entrevista',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            if (selection.selected) {
                              CandidateSelectionService.removeCandidate(
                                selection,
                              );
                            } else {
                              CandidateSelectionService.selectCandidate(
                                selection,
                              );
                            }
                          });
                        },
                        child: Text(
                          selection.selected ? 'Quitar' : 'Seleccionar',
                        ),
                      ),
                    ),
                  );
                }),
                if (manualSelections.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Candidatos agregados manualmente',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...manualSelections.map(
                    (selection) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(selection.candidate.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Agregado manualmente'),
                            if (selection.interviewEligible)
                              const Text(
                                'Apto para entrevista',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              CandidateSelectionService.removeCandidate(
                                selection,
                              );
                            });
                          },
                          child: const Text('Quitar'),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmSelection,
                child: const Text('Confirmar selección'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
