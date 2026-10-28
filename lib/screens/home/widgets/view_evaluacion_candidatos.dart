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
  Map<String, String> _candidatePostulationMap = {};
  Map<String, String> _candidateEstadoMap = {};
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
      final rawCandidatesData = await _vacancyService
          .fetchCandidatesWithPostulationId(widget.vacancy.id);

      List<CandidateModel> candidates = [];
      Map<String, String> candidatePostulationMap = {};
      Map<String, String> candidateEstadoMap = {};

      for (var data in rawCandidatesData) {
        final postulacionId = data['postulacion_id']?.toString();
        final estado = data['estado_postulacion']?.toString() ?? 'enviada';

        final candidateMap = {
          'id': data['id'],
          'full_name': data['full_name'],
          'email': data['email'],
          'phone': data['phone'],
          'resume_data': data['resume_data'],
          'created_by': data['created_by'],
        };

        final candidate = CandidateModel.fromMap(candidateMap);
        candidates.add(candidate);

        if (postulacionId != null) {
          candidatePostulationMap[candidate.id] = postulacionId;
          candidateEstadoMap[candidate.id] = estado;
        }
      }

      // 2. Ejecutar la evaluación con los criterios de esta vacante
      final evaluations = await _vacancyService.evaluateCandidates(
        vacancy: widget.vacancy,
        candidates: candidates,
      );

      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _evaluations = evaluations;
        _candidatePostulationMap = candidatePostulationMap;
        _candidateEstadoMap = candidateEstadoMap;
      });
    } catch (e) {
      print('Error al cargar y evaluar candidatos: $e');
      print(StackTrace.current);
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
                        final isEligibleTab = _resultTab == 0;
                        final postulacionId =
                            _candidatePostulationMap[candidate.id];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isEligibleTab
                                  ? AppTheme.lightGreenBg
                                  : Colors.red.shade50,
                              child: Text(
                                candidate.fullName.isNotEmpty
                                    ? candidate.fullName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(candidate.fullName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eval?.meetsCriteria == true
                                      ? 'Cumple con los requisitos'
                                      : (eval?.exclusionReasons.join(', ') ??
                                            'No cumple criterios'),
                                ),
                                Text(
                                  'Estado: ${_candidateEstadoMap[candidate.id] ?? 'enviada'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: isEligibleTab
                                ? (_candidateEstadoMap[candidate.id] ==
                                          'aceptada'
                                      ? const Chip(
                                          avatar: Icon(
                                            Icons.check_circle,
                                            color: AppTheme.primaryGreen,
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Aceptado',
                                            style: TextStyle(
                                              color: AppTheme.primaryGreen,
                                            ),
                                          ),
                                          backgroundColor:
                                              AppTheme.lightGreenBg,
                                        )
                                      : FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryGreen,
                                          ),
                                          icon: const Icon(
                                            Icons.check,
                                            size: 16,
                                          ),
                                          label: const Text('Aceptar'),
                                          onPressed: postulacionId == null
                                              ? null
                                              : () async {
                                                  try {
                                                    await _vacancyService
                                                        .actualizarEstadoPostulacion(
                                                          postulacionId,
                                                          'aceptada',
                                                        );

                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Candidato aceptado. Ahora podrá agendar su entrevista.',
                                                        ),
                                                        backgroundColor:
                                                            AppTheme
                                                                .primaryGreen,
                                                      ),
                                                    );

                                                    _loadAndEvaluate();
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Error al aceptar candidato: $e',
                                                        ),
                                                        backgroundColor:
                                                            Colors.redAccent,
                                                      ),
                                                    );
                                                  }
                                                },
                                        ))
                                : null,
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
