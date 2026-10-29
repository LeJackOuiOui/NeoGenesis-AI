import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/hr_assistant_service.dart';
import '../../../main.dart';

class ViewHrAssistantInbox extends StatefulWidget {
  const ViewHrAssistantInbox({super.key});

  @override
  State<ViewHrAssistantInbox> createState() => _ViewHrAssistantInboxState();
}

class _ViewHrAssistantInboxState extends State<ViewHrAssistantInbox> {
  late final HrAssistantService _service;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = HrAssistantService(supabase);
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.getEscalatedInteractions();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _answer(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder consulta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['question']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 3000,
              decoration: const InputDecoration(
                labelText: 'Respuesta para el empleado',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Enviar respuesta'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (answer == null || !mounted) return;

    try {
      await _service.answerEscalatedInteraction(
        interactionId: item['id'].toString(),
        answer: answer,
      );
      await _loadInbox();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta enviada al empleado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la respuesta: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consultas derivadas a RRHH',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Responde las preguntas que el asistente no pudo resolver con confianza.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _isLoading ? null : _loadInbox,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  _buildError()
                else if (_items.isEmpty)
                  _buildEmpty()
                else
                  ..._items.map(_buildItem),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Card(
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: Colors.redAccent),
      title: const Text('No se pudo cargar la bandeja.'),
      subtitle: Text(_error!),
      trailing: TextButton(onPressed: _loadInbox, child: const Text('Reintentar')),
    ),
  );

  Widget _buildEmpty() => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 42, color: Colors.grey[500]),
            const SizedBox(height: 10),
            const Text('No hay consultas pendientes de respuesta.'),
          ],
        ),
      ),
    ),
  );

  Widget _buildItem(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item['employee_name'] ?? 'Empleado'} · ${item['employee_email'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (createdAt != null)
                  Text(
                    MaterialLocalizations.of(context).formatShortDate(createdAt),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item['question']?.toString() ?? ''),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _answer(item),
                icon: const Icon(Icons.reply_rounded),
                label: const Text('Responder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
