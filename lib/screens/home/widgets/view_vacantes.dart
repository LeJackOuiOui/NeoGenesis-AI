import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/models/vacancy_model.dart';
import '../../../data/services/candidate_service.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';
import 'view_evaluacion_candidatos.dart';

class ViewVacantes extends StatefulWidget {
  const ViewVacantes({super.key});

  @override
  State<ViewVacantes> createState() => _ViewVacantesState();
}

class _ViewVacantesState extends State<ViewVacantes> {
  final _vacancyService = VacancyService(supabase);
  final _candidateService = CandidateService(supabase);
  List<VacancyModel> _vacancies = [];
  List<CandidateModel> _candidates = [];
  Map<String, CandidateEvaluation> _evaluations = {};
  VacancyModel? _selectedVacancy;
  bool _isLoading = true;
  bool _isEvaluating = false;
  int _resultTab = 0;
  String? _error;
  Map<String, int> _conteoPostulaciones = {};

  bool get _isRRHH {
    final metadata = supabase.auth.currentUser?.userMetadata;
    final role = metadata?['role']?.toString().toLowerCase();
    return metadata?['isRRHH'] == true ||
        role == 'responsable rrhh' ||
        role == 'responsable de recursos humanos';
  }

  final Set<String> _postulatedVacancyIds = {};

  static const _educationOptions = <String, String>{
    'none': 'Sin mínimo',
    'secondary': 'Secundaria',
    'technical': 'Técnica / tecnológica',
    'bachelor': 'Universitaria (licenciatura/ingeniería)',
    'postgraduate': 'Posgrado',
    'doctorate': 'Doctorado',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? preferredVacancyId}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _vacancyService.fetchVacancies(),
        _candidateService.fetchCandidates(),
        _loadPostulacionesList(),
        _vacancyService.fetchConteoPostulaciones(),
      ]);

      final vacancies = results[0] as List<VacancyModel>;
      final candidates = results[1] as List<CandidateModel>;
      final conteo = results[3] as Map<String, int>;

      if (!mounted) return;
      setState(() {
        _vacancies = vacancies;
        _candidates = candidates;
        _conteoPostulaciones = conteo;
        if (vacancies.isNotEmpty) {
          if (preferredVacancyId != null) {
            _selectedVacancy = vacancies.firstWhere(
              (v) => v.id == preferredVacancyId,
              orElse: () => vacancies.first,
            );
          } else if (_selectedVacancy == null ||
              !vacancies.any((v) => v.id == _selectedVacancy?.id)) {
            _selectedVacancy = vacancies.first;
          }
        } else {
          _selectedVacancy = null;
        }
      });

      if (_selectedVacancy != null && _isRRHH) {
        await _evaluate(_selectedVacancy!);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPostulacionesList() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await supabase
          .from('postulaciones')
          .select('vacante_id')
          .eq('usuario_id', userId);

      if (!mounted) return;
      setState(() {
        _postulatedVacancyIds.clear();
        _postulatedVacancyIds.addAll(
          (response as List).map((row) => row['vacante_id'].toString()),
        );
      });
    } catch (_) {}
  }

  Future<void> _evaluate(VacancyModel vacancy) async {
    setState(() => _isEvaluating = true);
    try {
      final evaluations = await _vacancyService.evaluateCandidates(
        vacancy: vacancy,
        candidates: _candidates,
      );
      if (mounted && _selectedVacancy?.id == vacancy.id) {
        setState(() => _evaluations = evaluations);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  Future<void> _showVacancyDialog({VacancyModel? vacancy}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: vacancy?.title ?? '');
    final experienceController = TextEditingController(
      text: vacancy?.minExperienceYears.toString() ?? '0',
    );
    final skillsController = TextEditingController(
      text: vacancy?.requiredSkills.join(', ') ?? '',
    );
    var educationLevel = vacancy?.minEducationLevel ?? 'none';
    VacancyModel? saved;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(vacancy == null ? 'Crear vacante' : 'Editar criterios'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la vacante *',
                        hintText: 'Ej. Analista de datos',
                      ),
                      validator: (value) => FormValidators.requiredText(
                        value,
                        label: 'El nombre de la vacante',
                        maxLength: 100,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: experienceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [FormValidators.decimalInputFormatter],
                      decoration: const InputDecoration(
                        labelText: 'Experiencia mínima (años)',
                      ),
                      validator: (value) => FormValidators.positiveNumber(
                        value,
                        label: 'La experiencia mínima',
                        allowZero: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: skillsController,
                      maxLines: 2,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Habilidades requeridas',
                        hintText: 'Dart, SQL, análisis de datos',
                        helperText:
                            'Separadas por comas. Todas son obligatorias.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: educationLevel,
                      decoration: const InputDecoration(
                        labelText: 'Nivel mínimo de formación',
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
                        if (value != null) {
                          setDialogState(() => educationLevel = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  saved = await _vacancyService.saveVacancy(
                    id: vacancy?.id,
                    title: titleController.text,
                    minExperienceYears: double.parse(
                      experienceController.text.trim().replaceAll(',', '.'),
                    ),
                    requiredSkills: skillsController.text
                        .split(',')
                        .map((skill) => skill.trim())
                        .where((skill) => skill.isNotEmpty)
                        .toSet()
                        .toList(),
                    minEducationLevel: educationLevel,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (mounted) _showMessage('No se pudo guardar: $error', true);
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar y evaluar'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    experienceController.dispose();
    skillsController.dispose();
    if (saved != null && mounted) {
      await _load(preferredVacancyId: saved!.id);
    }
  }

  Future<void> _confirmDeleteVacancy(VacancyModel vacancy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar vacante'),
        content: Text(
          '¿Eliminar "${vacancy.title}" y sus resultados de evaluación? '
          'Los candidatos no se eliminarán del sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar vacante'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _vacancyService.deleteVacancy(vacancy.id);
      if (!mounted) return;
      setState(() {
        _selectedVacancy = null;
        _evaluations = {};
      });
      await _load();
      if (mounted) {
        _showMessage('Vacante eliminada. Los candidatos siguen intactos.');
      }
    } catch (error) {
      if (mounted) _showMessage('No se pudo eliminar la vacante: $error', true);
    }
  }

  Future<void> _confirmRemoveCandidate(
    CandidateModel candidate, {
    required bool isRemoved,
  }) async {
    final vacancy = _selectedVacancy;
    if (vacancy == null) return;

    if (isRemoved) {
      try {
        await _vacancyService.restoreCandidateToVacancy(
          vacancyId: vacancy.id,
          candidateId: candidate.id,
        );
        await _load(preferredVacancyId: vacancy.id);
        if (mounted) _showMessage('Candidato restaurado en la vacante.');
      } catch (error) {
        if (mounted) _showMessage('No se pudo restaurar: $error', true);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar persona de la vacante'),
        content: Text(
          '¿Quitar a ${candidate.fullName} de "${vacancy.title}"? '
          'No se eliminará de la tabla de candidatos y podrás restaurarlo después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitar de vacante'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _vacancyService.removeCandidateFromVacancy(
        vacancyId: vacancy.id,
        candidateId: candidate.id,
      );
      await _load(preferredVacancyId: vacancy.id);
      if (mounted) {
        _showMessage('Persona quitada de la vacante; su perfil se conserva.');
      }
    } catch (error) {
      if (mounted) _showMessage('No se pudo quitar a la persona: $error', true);
    }
  }

  void _showMessage(String message, [bool isError = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final removedIds =
        _selectedVacancy?.removedCandidateIds.toSet() ?? <String>{};
    final eligible = _candidates.where((candidate) {
      return _evaluations[candidate.id]?.meetsCriteria == true;
    }).toList();
    final excluded = _candidates.where((candidate) {
      return _evaluations[candidate.id]?.meetsCriteria == false;
    }).toList();
    final removed = _candidates
        .where((candidate) => removedIds.contains(candidate.id))
        .toList();

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const title = Text(
                      'Vacantes disponibles',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    );

                    final button = _isRRHH
                        ? FilledButton.icon(
                            onPressed: () => _showVacancyDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva vacante'),
                          )
                        : const SizedBox.shrink();

                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          if (_isRRHH) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: button,
                            ),
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(child: title),
                        if (_isRRHH) ...[const SizedBox(width: 24), button],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const LinearProgressIndicator(color: AppTheme.primaryGreen),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(_error!),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ),
                ],
                if (!_isLoading && _vacancies.isEmpty && _error == null)
                  _emptyVacancies(),
                if (_vacancies.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  // LISTA VERTICAL DE VACANTES
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vacancies.length,
                    itemBuilder: (context, index) {
                      final vacancy = _vacancies[index];
                      final yaPostulado = _postulatedVacancyIds.contains(
                        vacancy.id,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      vacancy.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  // El símbolo de verificado sale únicamente si NO es RRHH / Empresa
                                  if (!_isRRHH &&
                                      vacancy.companyVerificationStatus ==
                                          'verified') ...[
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: AppTheme.primaryGreen,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (_isRRHH) ...[
                                    // Tus botones de edición y eliminación para RRHH...
                                    IconButton(
                                      tooltip: 'Editar vacante',
                                      onPressed: () =>
                                          _showVacancyDialog(vacancy: vacancy),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Eliminar vacante',
                                      onPressed: () =>
                                          _confirmDeleteVacancy(vacancy),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _criterionChip(
                                    Icons.work_history_outlined,
                                    '${vacancy.minExperienceYears.toStringAsFixed(1)} años mínimo',
                                  ),
                                  _criterionChip(
                                    Icons.school_outlined,
                                    _educationOptions[vacancy
                                            .minEducationLevel] ??
                                        'Formación',
                                  ),
                                  ...vacancy.requiredSkills.map(
                                    (skill) => _criterionChip(
                                      Icons.verified_outlined,
                                      skill,
                                    ),
                                  ),
                                ],
                              ),

                              if (_isRRHH) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.lightGreenBg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.people_alt_outlined,
                                            size: 16,
                                            color: AppTheme.primaryGreen,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_conteoPostulaciones[vacancy.id] ?? 0} postulaciones',
                                            style: const TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        // Navegar a tu pantalla de evaluación independiente
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ViewEvaluacionCandidatos(
                                                  vacancy: vacancy,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.analytics_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Ver candidatos y filtrar',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.textDark,
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // BOTÓN INTELIGENTE DE POSTULACIÓN / CANCELACIÓN PARA USUARIOS NORMALES
                              if (!_isRRHH) ...[
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        if (yaPostulado) {
                                          await _vacancyService
                                              .cancelarPostulacion(vacancy.id);
                                          setState(() {
                                            _postulatedVacancyIds.remove(
                                              vacancy.id,
                                            );
                                          });
                                          if (!context.mounted) return;
                                          _showMessage(
                                            'Has cancelado tu postulación exitosamente.',
                                          );
                                        } else {
                                          await _vacancyService.aplicarAVacante(
                                            vacancy.id,
                                          );
                                          setState(() {
                                            _postulatedVacancyIds.add(
                                              vacancy.id,
                                            );
                                          });
                                          if (!context.mounted) return;
                                          _showMessage(
                                            '¡Te has postulado a la vacante exitosamente!',
                                          );
                                        }
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        _showMessage(
                                          'No se pudo completar la solicitud: $e',
                                          true,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: yaPostulado
                                          ? Colors.red.shade50
                                          : AppTheme.primaryGreen,
                                      foregroundColor: yaPostulado
                                          ? Colors.red.shade700
                                          : Colors.white,
                                      elevation: yaPostulado ? 0 : 2,
                                      side: yaPostulado
                                          ? BorderSide(
                                              color: Colors.red.shade200,
                                            )
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: Icon(
                                      yaPostulado
                                          ? Icons.cancel_outlined
                                          : Icons.send_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      yaPostulado
                                          ? 'Cancelar postulación'
                                          : 'Postularme a esta vacante',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _criterionChip(IconData icon, String label) => Chip(
    avatar: Icon(icon, size: 17, color: AppTheme.primaryGreen),
    label: Text(label),
    backgroundColor: AppTheme.lightGreenBg,
    side: BorderSide.none,
    visualDensity: VisualDensity.compact,
  );

  Widget _buildResultsHeader(
    int eligibleCount,
    int excludedCount,
    int removedCount,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Resultado del filtro',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton.icon(
            onPressed: _selectedVacancy == null || _isEvaluating
                ? null
                : () => _evaluate(_selectedVacancy!),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reevaluar'),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text('Cumplen ($eligibleCount)'),
            selected: _resultTab == 0,
            onSelected: (_) => setState(() => _resultTab = 0),
          ),
          ChoiceChip(
            label: Text('Excluidos ($excludedCount)'),
            selected: _resultTab == 1,
            onSelected: (_) => setState(() => _resultTab = 1),
          ),
          ChoiceChip(
            label: Text('Quitados ($removedCount)'),
            selected: _resultTab == 2,
            onSelected: (_) => setState(() => _resultTab = 2),
          ),
        ],
      ),
    ],
  );

  Widget _candidateResultCard(
    CandidateModel candidate,
    CandidateEvaluation? evaluation, {
    required bool excluded,
    required bool removed,
  }) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: removed || excluded
              ? Colors.red.shade50
              : AppTheme.lightGreenBg,
          foregroundColor: removed || excluded
              ? Colors.red.shade700
              : AppTheme.primaryGreen,
          child: Text(
            candidate.fullName.isEmpty
                ? '?'
                : candidate.fullName[0].toUpperCase(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (candidate.email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(candidate.email),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: removed
              ? 'Restaurar en esta vacante'
              : 'Quitar de esta vacante',
          onPressed: () =>
              _confirmRemoveCandidate(candidate, isRemoved: removed),
          icon: Icon(
            removed ? Icons.person_add_alt_1 : Icons.person_remove_outlined,
            color: removed ? AppTheme.primaryGreen : Colors.redAccent,
          ),
        ),
      ],
    ),
  );

  Widget _emptyVacancies() => _emptyCard(
    Icons.work_outline,
    'Aún no hay vacantes',
    'Crea una vacante para definir experiencia, habilidades y formación mínimas.',
  );

  Widget _emptyResults(int resultTab) => _emptyCard(
    resultTab == 2
        ? Icons.person_remove_outlined
        : resultTab == 1
        ? Icons.verified_outlined
        : Icons.person_search_outlined,
    resultTab == 2
        ? 'No hay personas quitadas de esta vacante'
        : resultTab == 1
        ? 'No hay candidatos excluidos'
        : 'Ningún candidato cumple todavía',
    'Detalle de la evaluación en curso.',
  );

  Widget _emptyCard(IconData icon, String title, String detail) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Icon(icon, size: 36, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );

  Widget _errorCard(String message) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'No se pudo cargar o evaluar. $message',
      style: TextStyle(color: Colors.red.shade800),
    ),
  );
}
