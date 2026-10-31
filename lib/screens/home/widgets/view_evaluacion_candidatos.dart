import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../data/models/candidate.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/models/job.dart';
import '../../../data/models/vacancy_model.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';
import '../candidate_ranking_screen.dart';

class ViewEvaluacionCandidatos extends StatefulWidget {
  final VacancyModel vacancy;

  const ViewEvaluacionCandidatos({super.key, required this.vacancy});

  @override
  State<ViewEvaluacionCandidatos> createState() =>
      _ViewEvaluacionCandidatosState();
}

class _ViewEvaluacionCandidatosState extends State<ViewEvaluacionCandidatos> {
  final _vacancyService = VacancyService(supabase);

  List<CandidateModel> _candidates = [];
  Map<String, CandidateEvaluation> _evaluations = {};
  Map<String, String> _candidatePostulationMap = {};
  Map<String, String> _candidateEstadoMap = {};

  bool _isLoading = true;
  String? _error;

  int _resultTab = 0;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedEducationLevel = 'all';

  static const _educationOptions = <String, String>{
    'all': 'Todos los niveles',
    'none': 'Sin mínimo',
    'secondary': 'Secundaria',
    'technical': 'Técnica / tecnológica',
    'bachelor': 'Universitaria',
    'postgraduate': 'Posgrado',
    'doctorate': 'Doctorado',
  };

  @override
  void initState() {
    super.initState();

    _loadAndEvaluate();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndEvaluate() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Consultar candidatos postulados a la vacante.
      final rawCandidatesData = await _vacancyService
          .fetchCandidatesWithPostulationId(widget.vacancy.id);

      List<CandidateModel> candidates = [];
      Map<String, String> candidatePostulationMap = {};
      Map<String, String> candidateEstadoMap = {};

      // 2. Convertir los datos recibidos desde Supabase.
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

      // 3. Evaluar candidatos según los criterios de la vacante.
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
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar los candidatos.\nDetalle: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Abrir el ranking utilizando los candidatos reales de Supabase.
  void _openRanking(List<CandidateModel> candidates) {
    final rankingCandidates = candidates.map((candidate) {
      final resumeData = candidate.resumeData;

      final skills =
          (resumeData['skills'] as List?)
              ?.map((skill) => skill.toString())
              .toList() ??
          [];

      final experienceYears =
          double.tryParse(resumeData['experience_years']?.toString() ?? '') ??
          0;

      final cvText = resumeData.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');

      return Candidate(
        id: candidate.id,
        name: candidate.fullName,
        cvText: cvText,
        skills: skills,
        experienceYears: experienceYears,
      );
    }).toList();

    final job = Job(
      id: widget.vacancy.id,
      title: widget.vacancy.title,
      description:
          'Experiencia mínima: ${widget.vacancy.minExperienceYears} años. '
          'Habilidades requeridas: ${widget.vacancy.requiredSkills.join(', ')}.',
      requiredSkills: widget.vacancy.requiredSkills,
      requiredExperienceYears: widget.vacancy.minExperienceYears,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CandidateRankingScreen(
          candidates: rankingCandidates,
          job: job,
          vacancyId: widget.vacancy.id,
        ),
      ),
    );
  }

  // Filtrar candidatos por texto y nivel educativo.
  bool _matchesSearch(CandidateModel candidate) {
    final resumeData = candidate.resumeData;

    if (_selectedEducationLevel != null && _selectedEducationLevel != 'all') {
      final candEdu =
          resumeData['education_level']?.toString().toLowerCase() ?? '';

      if (candEdu != _selectedEducationLevel) {
        return false;
      }
    }

    if (_searchQuery.isEmpty) return true;

    // Buscar por nombre.
    if (candidate.fullName.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    // Buscar por cargo o posición.
    if (candidate.profilePosition != null &&
        candidate.profilePosition!.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    // Buscar por habilidades.
    if (resumeData.isNotEmpty) {
      final skills =
          (resumeData['skills'] as List?)
              ?.map((s) => s.toString().toLowerCase())
              .toList() ??
          [];

      if (skills.any((skill) => skill.contains(_searchQuery))) {
        return true;
      }

      final additionalInfo =
          resumeData['additional_info']?.toString().toLowerCase() ?? '';

      if (additionalInfo.contains(_searchQuery)) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final removedIds = widget.vacancy.removedCandidateIds.toSet();

    final eligible = _candidates.where((c) {
      return _evaluations[c.id]?.meetsCriteria == true &&
          !removedIds.contains(c.id) &&
          _matchesSearch(c);
    }).toList();

    final excluded = _candidates.where((c) {
      return _evaluations[c.id]?.meetsCriteria == false &&
          !removedIds.contains(c.id) &&
          _matchesSearch(c);
    }).toList();

    final removed = _candidates
        .where((c) => removedIds.contains(c.id) && _matchesSearch(c))
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
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ocurrió un problema',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadAndEvaluate,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de búsqueda.
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar por habilidad, cargo o nombre',
                      hintText: 'Ej. Dart, Analista, Juan...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.primaryGreen,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filtro por nivel educativo.
                  DropdownButtonFormField<String>(
                    value: _selectedEducationLevel ?? 'all',
                    decoration: InputDecoration(
                      labelText: 'Nivel de formación',
                      prefixIcon: const Icon(
                        Icons.school_outlined,
                        color: AppTheme.primaryGreen,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _educationOptions.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedEducationLevel = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Botón para generar el ranking.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: eligible.isEmpty
                          ? null
                          : () => _openRanking(eligible),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('Generar ranking de candidatos'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pestañas de resultados.
                  Wrap(
                    spacing: 10,
                    children: [
                      ChoiceChip(
                        label: Text('Cumplen (${eligible.length})'),
                        selected: _resultTab == 0,
                        onSelected: (_) {
                          setState(() => _resultTab = 0);
                        },
                      ),
                      ChoiceChip(
                        label: Text('Excluidos (${excluded.length})'),
                        selected: _resultTab == 1,
                        onSelected: (_) {
                          setState(() => _resultTab = 1);
                        },
                      ),
                      ChoiceChip(
                        label: Text('Quitados (${removed.length})'),
                        selected: _resultTab == 2,
                        onSelected: (_) {
                          setState(() => _resultTab = 2);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (displayed.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          _searchQuery.isNotEmpty ||
                                  _selectedEducationLevel != 'all'
                              ? 'No se encontraron candidatos que coincidan con los filtros aplicados.'
                              : (_resultTab == 0
                                    ? 'Ningún candidato cumple los criterios actualmente'
                                    : _resultTab == 1
                                    ? 'No hay candidatos excluidos'
                                    : 'No hay candidatos quitados'),
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

                        // Datos del CV.
                        final skillsList =
                            (candidate.resumeData['skills'] as List?)
                                ?.map((s) => s.toString())
                                .toList() ??
                            [];

                        final expYears =
                            candidate.resumeData['experience_years'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
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
                                  title: Text(
                                    candidate.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        eval?.meetsCriteria == true
                                            ? 'Cumple con los requisitos'
                                            : (eval?.exclusionReasons.join(
                                                    ', ',
                                                  ) ??
                                                  'No cumple criterios'),
                                      ),
                                      const SizedBox(height: 2),
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
                                                    color:
                                                        AppTheme.primaryGreen,
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

                                                          if (!mounted) {
                                                            return;
                                                          }

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
                                                          if (!mounted) {
                                                            return;
                                                          }

                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'Error al aceptar candidato: $e',
                                                              ),
                                                              backgroundColor:
                                                                  Colors
                                                                      .redAccent,
                                                            ),
                                                          );
                                                        }
                                                      },
                                              ))
                                      : null,
                                ),

                                // Habilidades y experiencia.
                                if (skillsList.isNotEmpty ||
                                    expYears != null) ...[
                                  const Divider(height: 16),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (expYears != null)
                                        Chip(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: Colors.grey.shade100,
                                          label: Text('$expYears años de exp.'),
                                        ),
                                      ...skillsList.map(
                                        (skill) => Chip(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor:
                                              AppTheme.lightGreenBg,
                                          label: Text(
                                            skill,
                                            style: const TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
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
