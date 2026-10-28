import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/candidate_interview_service.dart';

class CandidateScheduleSelectionScreen extends StatefulWidget {
  final String vacancyId;
  final String recruiterId;
  final String candidateId;

  const CandidateScheduleSelectionScreen({
    super.key,
    required this.vacancyId,
    required this.recruiterId,
    required this.candidateId,
  });

  @override
  State<CandidateScheduleSelectionScreen> createState() =>
      _CandidateScheduleSelectionScreenState();
}

class _CandidateScheduleSelectionScreenState
    extends State<CandidateScheduleSelectionScreen> {
  final _service = CandidateInterviewService();
  late Future<List<Map<String, dynamic>>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _service.getAvailableSlotsForVacancy(widget.vacancyId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Entrevista de Trabajo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¡Tu postulación ha sido aceptada! Selecciona el horario que mejor se adapte a ti:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _slotsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final slots = snapshot.data ?? [];
                  if (slots.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay horarios disponibles en este momento.',
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.event_available,
                            color: Colors.green,
                          ),
                          title: Text('Fecha: ${slot['date']}'),
                          subtitle: Text(
                            'Horario: ${slot['start_time']} - ${slot['end_time']}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              try {
                                final scheduledDate = DateTime.parse(
                                  '${slot['date']} ${slot['start_time']}',
                                );

                                // 1. Asegurar que obtenemos el ID real de la tabla 'candidatos'
                                // (por si se pasó el ID de autenticación previamente)
                                final candidateRow = await Supabase
                                    .instance
                                    .client
                                    .from('candidatos')
                                    .select('id')
                                    .or(
                                      'id.eq.${widget.candidateId},created_by.eq.${widget.candidateId}',
                                    )
                                    .maybeSingle();

                                final actualCandidateId =
                                    candidateRow?['id']?.toString() ??
                                    widget.candidateId;

                                // 2. Guardar el registro en la tabla 'interviews' y reservar el horario
                                await _service.bookInterview(
                                  vacancyId: widget.vacancyId,
                                  candidateId: actualCandidateId,
                                  recruiterId: widget.recruiterId,
                                  availabilityId: slot['id'],
                                  scheduledDateTime: scheduledDate,
                                );

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '¡Entrevista agendada con éxito!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al agendar: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            child: const Text('Seleccionar'),
                          ),
                        ),
                      );
                    },
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
