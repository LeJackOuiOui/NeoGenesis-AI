import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_theme.dart';
import 'widgets/custom_sidebar.dart';
import 'widgets/view_inicio.dart';
import 'widgets/view_vacantes.dart';
import 'widgets/view_logs.dart';
import 'widgets/view_perfil.dart';
import 'widgets/view_registros.dart';
import 'widgets/view_mi_cv.dart';
import 'widgets/view_hr_assistant.dart';
import 'widgets/view_hr_assistant_inbox.dart';
import '../../main.dart';
import '../auth/login_modal.dart';
import '../auth/register_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool? _sidebarExpanded;
  late final StreamSubscription<AuthState> _authSubscription;

  bool get _isAdmin {
    final role =
        (supabase.auth.currentUser?.userMetadata?['role'] as String?)
            ?.toLowerCase() ??
        '';
    return role == 'administrador' || role == 'admin';
  }

  bool get _isRRHH {
    final metadata = supabase.auth.currentUser?.userMetadata;
    final role = metadata?['role']?.toString().toLowerCase();
    return metadata?['isRRHH'] == true || role == 'responsable rrhh';
  }

  @override
  void initState() {
    super.initState();
    // Escuchar cambios de estado en la autenticación (Login / Logout)
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      if (mounted) {
        setState(() {
          // Si cierra sesión o deja de ser admin estando en una vista restringida, vuelve a Inicio
          if (event == AuthChangeEvent.signedIn || session != null) {
            if (_selectedIndex == 0) {
              _selectedIndex = 0;
            }
          } else if (session == null && _selectedIndex != 0) {
            _selectedIndex = 0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Widget _buildCurrentView() {
    switch (_selectedIndex) {
      case 1:
        return const ViewVacantes();
      case 2:
        return (!_isAdmin && !_isRRHH) ? const ViewMiCv() : const ViewPerfil();
      case 3:
        return (!_isAdmin && !_isRRHH)
            ? const ViewPerfil()
            : (_isAdmin ? const ViewRegistros() : const ViewInicio());
      case 4:
        if (_isAdmin) return const ViewRegistros();
        return (!_isRRHH && supabase.auth.currentSession != null)
            ? const ViewHrAssistant()
            : const ViewInicio();
      case 5:
        return _isAdmin ? const ViewLogs() : const ViewInicio();
      case 6:
        return (_isAdmin || _isRRHH)
            ? const ViewHrAssistantInbox()
            : const ViewInicio();
      case 0:
      default:
        return const ViewInicio();
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _onLogoutPressed() async {
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      setState(() {
        _selectedIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada correctamente.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cerrar sesión: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- MODAL CENTRADO DE REGISTRO ---
  void _showRegisterOptionsModal() {
    final screenContext = context;
    showDialog(
      context: screenContext,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.textDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Crear una cuenta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona cómo quieres registrarte en NEOGENESIS IA:',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildModalOption(
                icon: Icons.person_outline,
                title: 'Registrarme como usuario',
                subtitle: 'Crea una cuenta personal',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: screenContext,
                    builder: (context) => const RegisterModal(isRRHH: false),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildModalOption(
                icon: Icons.business_outlined,
                title: 'Registrarme como empresa',
                subtitle: 'Crea una cuenta para gestionar procesos de RRHH',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: screenContext,
                    builder: (context) => const RegisterModal(isRRHH: true),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLoginOptionsModal() {
    final screenContext = context;
    showDialog(
      context: screenContext,
      builder: (context) => const LoginModal(),
    );
  }

  Widget _buildModalOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    double iconSize = 22,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: iconSize),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = supabase.auth.currentSession != null;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSidebarExpanded =
              _sidebarExpanded ?? constraints.maxWidth < 900;
          final canExpandOnHover = constraints.maxWidth >= 900;

          return Row(
            children: [
              CustomSidebar(
                selectedIndex: _selectedIndex,
                isLoggedIn: isLoggedIn,
                isAdmin: _isAdmin,
                isRRHH: _isRRHH,
                isExpanded: isSidebarExpanded,
                onNavigationSelected: _onTabSelected,
                onHoverChanged: canExpandOnHover
                    ? (isHovered) {
                        setState(() {
                          _sidebarExpanded = isHovered;
                        });
                      }
                    : (_) {},
                onToggle: () {
                  setState(() {
                    _sidebarExpanded = !isSidebarExpanded;
                  });
                },
                onLoginPressed: _showLoginOptionsModal,
                onRegisterPressed: _showRegisterOptionsModal,
                onLogoutPressed: _onLogoutPressed,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFDCEFE4), Color(0xFFEAF4ED)],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -145,
                      right: -115,
                      child: Container(
                        width: 430,
                        height: 430,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryGreen.withValues(alpha: 0.16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(
                                alpha: 0.22,
                              ),
                              blurRadius: 110,
                              spreadRadius: 55,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildCurrentView(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
