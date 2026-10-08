import 'package:flutter/material.dart';

import '../../../config/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/candidate_model.dart';
import '../../../data/models/vacancy_model.dart';
import '../../../data/services/candidate_service.dart';
import '../../../data/services/vacancy_service.dart';
import '../../../main.dart';

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
      ]);
      final vacancies = results[0] as List<VacancyModel>;
      final candidates = results[1] as List<CandidateModel>;
      VacancyModel? selected;
      for (final vacancy in vacancies) {
        if (vacancy.id == (preferredVacancyId ?? _selectedVacancy?.id)) {
          selected = vacancy;
          break;
        }
      }
      selected ??= vacancies.isEmpty ? null : vacancies.first;
      if (mounted) {
        setState(() {
          _vacancies = vacancies;
          _candidates = candidates;
          _selectedVacancy = selected;
        });
      }
      if (selected != null) await _evaluate(selected);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      if (mounted)
        _showMessage('Vacante eliminada. Los candidatos siguen intactos.');
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
      if (mounted)
        _showMessage('Persona quitada de la vacante; su perfil se conserva.');
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
    final displayed = switch (_resultTab) {
      1 => excluded,
      2 => removed,
      _ => eligible,
    };

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
                      'Vacantes y evaluación',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    );
                    final button = FilledButton.icon(
                      onPressed: () => _showVacancyDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva vacante'),
                    );
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: button,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Expanded(child: title),
                        const SizedBox(width: 24),
                        button,
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
                  const Text(
                    'Selecciona una vacante',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _vacancies.map(_vacancyChip).toList(),
                  ),
                  if (_selectedVacancy != null) ...[
                    const SizedBox(height: 20),
                    _criteriaCard(_selectedVacancy!),
                    const SizedBox(height: 20),
                    _buildResultsHeader(
                      eligible.length,
                      excluded.length,
                      removed.length,
                    ),
                    const SizedBox(height: 12),
                    if (_isEvaluating)
                      const LinearProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    if (!_isEvaluating && displayed.isEmpty)
                      _emptyResults(_resultTab),
                    ...displayed.map(
                      (candidate) => _candidateResultCard(
                        candidate,
                        _evaluations[candidate.id],
                        excluded: _resultTab == 1,
                        removed: _resultTab == 2,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vacancyChip(VacancyModel vacancy) {
    final selected = vacancy.id == _selectedVacancy?.id;
    return OutlinedButton.icon(
      onPressed: () async {
        setState(() {
          _selectedVacancy = vacancy;
          _evaluations = {};
          _resultTab = 0;
        });
        await _evaluate(vacancy);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppTheme.textDark : Colors.white,
        foregroundColor: selected ? Colors.white : AppTheme.textDark,
        side: BorderSide(
          color: selected ? AppTheme.textDark : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(selected ? Icons.work : Icons.work_outline, size: 18),
      label: Text(vacancy.title),
    );
  }

  Widget _criteriaCard(VacancyModel vacancy) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
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
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar criterios',
              onPressed: () => _showVacancyDialog(vacancy: vacancy),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Eliminar vacante',
              onPressed: () => _confirmDeleteVacancy(vacancy),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ],
        ),
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
              _educationOptions[vacancy.minEducationLevel] ?? 'Formación',
            ),
            ...vacancy.requiredSkills.map(
              (skill) => _criterionChip(Icons.verified_outlined, skill),
            ),
          ],
        ),
      ],
    ),
  );

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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
    margin: const EdgeInsets.only(bottom: 10),
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
              if (excluded &&
                  (evaluation?.exclusionReasons.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                ...evaluation!.exclusionReasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    resultTab == 2
        ? 'Las personas que quites de la vacante aparecerán aquí y podrás restaurarlas.'
        : resultTab == 1
        ? 'Todos los candidatos registrados cumplen estos criterios.'
        : 'Sube o completa perfiles con los datos extraídos del CV y vuelve a evaluar.',
  );

  Widget _emptyCard(IconData icon, String title, String detail) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: Colors.grey.shade400),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
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
      'No se pudo cargar o evaluar. Aplica la migración 202610070004_create_vacantes.sql y verifica los permisos RLS. $message',
      style: TextStyle(color: Colors.red.shade800),
    ),
  );
}
