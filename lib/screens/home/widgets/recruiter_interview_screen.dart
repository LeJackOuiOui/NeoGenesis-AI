import '../../../main.dart';
import 'package:flutter/material.dart';
import '../../../data/services/candidate_selection_service.dart';
import 'view_horarios.dart';

class RecruiterInterviewScreen extends StatefulWidget {
  final String vacancyId;
  final String recruiterId;

  const RecruiterInterviewScreen({
    super.key,
    required this.vacancyId,
    required this.recruiterId,
  });

  @override
  State<RecruiterInterviewScreen> createState() =>
      _RecruiterInterviewScreenState();
}

class _RecruiterInterviewScreenState extends State<RecruiterInterviewScreen> {
  late Future<List<Map<String, dynamic>>> _candidatesFuture;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  void _loadCandidates() {
    _candidatesFuture = CandidateSelectionService.getConfirmedCandidates(
      client: supabase,
      vacancyId: widget.vacancyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar entrevistas')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _candidatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text('Error al cargar los candidatos: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(_loadCandidates);
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final candidates = snapshot.data ?? [];

          if (candidates.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay candidatos confirmados para esta vacante.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              final candidateId = candidate['id']?.toString() ?? '';
              final name =
                  candidate['full_name']?.toString() ?? 'Candidato sin nombre';
              final email = candidate['email']?.toString() ?? 'Sin correo';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name),
                  subtitle: Text(email),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: candidateId.isEmpty
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CandidateScheduleSelectionScreen(
                                    vacancyId: widget.vacancyId,
                                    recruiterId: widget.recruiterId,
                                    candidateId: candidateId,
                                  ),
                            ),
                          );
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
