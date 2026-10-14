import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/models/vacancy_model.dart';
import '../../../data/services/candidate_service.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';

class ViewEvaluacionCandidatos extends StatefulWidget {
  final VacancyModel vacancy;

  const ViewEvaluacionCandidatos({super.key, required this.vacancy});

  @override
  State<ViewEvaluacionCandidatos> createState() =>
      _ViewEvaluacionCandidatosState();
}

class _ViewEvaluacionCandidatosState extends State<ViewEvaluacionCandidatos> {
  final _vacancyService = VacancyService(supabase);
  final _candidateService = CandidateService(supabase);

  List<CandidateModel> _candidates = [];
  Map<String, CandidateEvaluation> _evaluations = {};
  bool _isLoading = true;
  int _resultTab = 0; // 0: Cumplen, 1: Excluidos, 2: Quitados

  @override
  void initState() {
    super.initState();
    _loadAndEvaluate();
  }

  Future<void> _loadAndEvaluate() async {
    setState(() => _isLoading = true);
    try {
      // 1. Cargar postulados de la vacante
      final candidates = await _candidateService.fetchPostulatedCandidates();

      // 2. Ejecutar la evaluación con los criterios de esta vacante
      final evaluations = await _vacancyService.evaluateCandidates(
        vacancy: widget.vacancy,
        candidates: candidates,
      );

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _evaluations = evaluations;
      });
    } catch (e) {
      // Manejo de error si aplica
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final removedIds = widget.vacancy.removedCandidateIds.toSet();

    final eligible = _candidates.where((c) {
      return _evaluations[c.id]?.meetsCriteria == true &&
          !removedIds.contains(c.id);
    }).toList();

    final excluded = _candidates.where((c) {
      return _evaluations[c.id]?.meetsCriteria == false &&
          !removedIds.contains(c.id);
    }).toList();

    final removed = _candidates
        .where((c) => removedIds.contains(c.id))
        .toList();

    final displayed = switch (_resultTab) {
      1 => excluded,
      2 => removed,
      _ => eligible,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluación: ${widget.vacancy.title}'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Reevaluar candidatos',
            onPressed: _isLoading ? null : _loadAndEvaluate,
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pestañas de estado del filtro
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: Text('Cumplen (${eligible.length})'),
                        selected: _resultTab == 0,
                        onSelected: (_) => setState(() => _resultTab = 0),
                      ),
                      ChoiceChip(
                        label: Text('Excluidos (${excluded.length})'),
                        selected: _resultTab == 1,
                        onSelected: (_) => setState(() => _resultTab = 1),
                      ),
                      ChoiceChip(
                        label: Text('Quitados (${removed.length})'),
                        selected: _resultTab == 2,
                        onSelected: (_) => setState(() => _resultTab = 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (displayed.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          _resultTab == 0
                              ? 'Ningún candidato cumple los criterios actualmente'
                              : _resultTab == 1
                              ? 'No hay candidatos excluidos'
                              : 'No hay candidatos quitados',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayed.length,
                      itemBuilder: (context, index) {
                        final candidate = displayed[index];
                        final eval = _evaluations[candidate.id];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _resultTab == 0
                                  ? AppTheme.lightGreenBg
                                  : Colors.red.shade50,
                              child: Text(
                                candidate.fullName.isNotEmpty
                                    ? candidate.fullName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(candidate.fullName),
                            subtitle: Text(
                              eval?.meetsCriteria == true
                                  ? 'Cumple con los requisitos'
                                  : (eval?.exclusionReasons.join(', ') ??
                                        'No cumple criterios'),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
