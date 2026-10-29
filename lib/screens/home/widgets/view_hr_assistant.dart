import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../data/services/hr_assistant_service.dart';
import '../../../main.dart';

class ViewHrAssistant extends StatefulWidget {
  const ViewHrAssistant({super.key});

  @override
  State<ViewHrAssistant> createState() => _ViewHrAssistantState();
}

class _ViewHrAssistantState extends State<ViewHrAssistant> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  late final HrAssistantService _service;
  List<Map<String, dynamic>> _interactions = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _service = HrAssistantService(supabase);
    _loadInteractions();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInteractions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final interactions = await _service.getMyInteractions();
      if (!mounted) return;
      setState(() => _interactions = interactions);
      _scrollToBottom();
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isSending) return;
    _questionController.clear();
    setState(() => _isSending = true);
    try {
      await _service.ask(question);
      await _loadInteractions();
    } catch (error) {
      if (!mounted) return;
      _questionController.text = question;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la pregunta: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textDark.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildConversation()),
                _buildComposer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF7FBF8),
        border: Border(bottom: BorderSide(color: Color(0xFFE7EEE9))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE0F4E7),
            foregroundColor: Color(0xFF168744),
            child: Icon(Icons.support_agent_rounded),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente de RRHH',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                SizedBox(height: 3),
                Text(
                  'Respuestas basadas en las políticas internas',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar conversación',
            onPressed: _isLoading ? null : _loadInteractions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    if (_isLoading && _interactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _interactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No se pudo cargar el historial.\n$_loadError'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadInteractions, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        if (_interactions.isEmpty) _buildWelcome(),
        for (final interaction in _interactions) ...[
          _buildMessage(
            content: interaction['question']?.toString() ?? '',
            isEmployee: true,
          ),
          const SizedBox(height: 14),
          _buildMessage(
            content: interaction['answer']?.toString() ??
                'Tu consulta está siendo procesada.',
            isEmployee: false,
            waitingForHr: interaction['status'] == 'waiting_for_hr',
            sources: interaction['sources'],
          ),
          const SizedBox(height: 22),
        ],
        if (_isSending)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 44),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 30),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 40, color: AppTheme.primaryGreen),
          const SizedBox(height: 14),
          const Text(
            '¿En qué podemos ayudarte?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pregunta sobre procesos y políticas internas. Si no encontramos una respuesta confiable, enviaremos tu consulta a RRHH.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _suggestion('¿Cómo solicito vacaciones?'),
              _suggestion('¿Cuál es el proceso de permisos?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _suggestion(String question) {
    return ActionChip(
      label: Text(question),
      onPressed: () {
        _questionController.text = question;
      },
    );
  }

  Widget _buildMessage({
    required String content,
    required bool isEmployee,
    bool waitingForHr = false,
    dynamic sources,
  }) {
    final sourceList = sources is List ? sources : const [];
    return Row(
      mainAxisAlignment: isEmployee
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEmployee) ...[
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE0F4E7),
            foregroundColor: Color(0xFF168744),
            child: Icon(Icons.auto_awesome, size: 17),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isEmployee
                  ? const Color(0xFF168744)
                  : const Color(0xFFF2F5F3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: TextStyle(
                    color: isEmployee ? Colors.white : AppTheme.textDark,
                    height: 1.45,
                  ),
                ),
                if (waitingForHr) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Consulta derivada a RRHH',
                    style: TextStyle(
                      color: Color(0xFF946200),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (!isEmployee && sourceList.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Fuentes: ${sourceList.map((item) => item is Map ? item['title'] : null).whereType<String>().join(', ')}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7EEE9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              onSubmitted: (_) => _sendQuestion(),
              decoration: InputDecoration(
                hintText: 'Escribe tu pregunta sobre procesos internos...',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF7F9F8),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'Enviar pregunta',
            onPressed: _isSending ? null : _sendQuestion,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(50, 50),
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
