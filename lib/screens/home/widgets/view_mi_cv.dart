import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../main.dart';

class ViewMiCv extends StatefulWidget {
  const ViewMiCv({super.key});

  @override
  State<ViewMiCv> createState() => _ViewMiCvState();
}

class _ViewMiCvState extends State<ViewMiCv> {
  final _formKey = GlobalKey<FormState>();
  final _experienceController = TextEditingController();
  final _skillsController = TextEditingController();
  final _additionalController = TextEditingController();

  String _educationLevel = 'bachelor';
  bool _isLoading = true;
  String? _candidateId;

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
    _loadCandidateData();
  }

  Future<void> _loadCandidateData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Buscamos si ya existe un registro en candidatos para este usuario
      final response = await supabase
          .from('candidatos')
          .select()
          .eq('created_by', user.id)
          .maybeSingle();

      if (response != null) {
        _candidateId = response['id'].toString();
        final resumeData =
            response['resume_data'] as Map<String, dynamic>? ?? {};

        _experienceController.text = (resumeData['experience_years'] ?? 0)
            .toString();
        _educationLevel = resumeData['education_level'] ?? 'bachelor';

        final skillsList = resumeData['skills'] is List
            ? (resumeData['skills'] as List).join(', ')
            : '';
        _skillsController.text = skillsList;

        _additionalController.text =
            resumeData['additional_info']?.toString() ?? '';
      }
    } catch (e) {
      // Manejar error de carga si es necesario
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCv() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final skills = _skillsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final resumeData = {
        'experience_years':
            double.tryParse(
              _experienceController.text.trim().replaceAll(',', '.'),
            ) ??
            0.0,
        'education_level': _educationLevel,
        'skills': skills,
        'additional_info': _additionalController.text.trim(),
      };

      if (_candidateId != null) {
        // Actualizar registro existente
        await supabase
            .from('candidatos')
            .update({
              'resume_data': resumeData,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', _candidateId!);
      } else {
        // Crear nuevo registro asociado al usuario
        final insertResponse = await supabase
            .from('candidatos')
            .insert({
              'full_name':
                  user.userMetadata?['full_name'] ??
                  user.email?.split('@').first ??
                  'Candidato',
              'email': user.email,
              'created_by': user.id,
              'resume_data': resumeData,
            })
            .select('id')
            .single();

        _candidateId = insertResponse['id'].toString();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hoja de vida actualizada correctamente.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _skillsController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi Hoja de Vida',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actualiza tu información profesional para que el sistema la compare automáticamente con las vacantes.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _experienceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FormValidators.decimalInputFormatter,
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Años de experiencia *',
                                  hintText: 'Ej. 2.5',
                                ),
                                validator: (val) =>
                                    FormValidators.positiveNumber(
                                      val,
                                      label: 'La experiencia',
                                      allowZero: true,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue:
                                    _educationOptions.containsKey(
                                      _educationLevel,
                                    )
                                    ? _educationLevel
                                    : 'bachelor',
                                decoration: const InputDecoration(
                                  labelText: 'Nivel máximo de educación *',
                                ),
                                items: _educationOptions.entries
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _educationLevel = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _skillsController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Conocimientos y Habilidades *',
                                  hintText: 'Dart, SQL, Flutter, Supabase',
                                  helperText: 'Sepáralos mediante comas (,)',
                                ),
                                validator: (val) => FormValidators.requiredText(
                                  val,
                                  label: 'Las habilidades',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _additionalController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Otra información relevante',
                                  hintText:
                                      'Certificaciones, proyectos destacados, idiomas...',
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saveCv,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text(
                                    'Guardar Hoja de Vida',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
