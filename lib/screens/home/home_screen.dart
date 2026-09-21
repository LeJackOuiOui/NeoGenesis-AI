import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_theme.dart';
import '../../main.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/custom_drawer.dart';
import 'widgets/view_inicio.dart';
import 'widgets/view_perfil.dart';
import 'widgets/view_registros.dart';

import '../auth/login_modal.dart';
import '../auth/register_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios de estado en la autenticación (Login / Logout)
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          // Si cierra sesión y estaba en una vista no permitida, vuelve a Inicio
          if (data.session == null && _selectedIndex != 0) {
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
        return const ViewRegistros();
      case 2:
        return const ViewPerfil();
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
                'Selecciona el método con el que deseas registrarte en NEOGENESIS IA:',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildModalOption(
                icon: Icons.email_outlined,
                title: 'Registrarse con Correo',
                subtitle: 'Crea tu cuenta con un correo y contraseña',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: screenContext,
                    builder: (context) => const RegisterModal(),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildModalOption(
                icon: Icons.g_mobiledata_rounded,
                iconSize: 28,
                title: 'Registrarse con Google',
                subtitle: 'Acceso rápido con tu cuenta Google',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registro con Google seleccionado'),
                    ),
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
                    'Iniciar Sesión',
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
                'Elige cómo quieres acceder a la plataforma:',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
              const SizedBox(height: 24),
              _buildModalOption(
                icon: Icons.person_outline,
                title: 'Iniciar Sesión (Usuario)',
                subtitle: 'Ingresa a tu portal de usuario',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: screenContext,
                    builder: (context) => const LoginModal(),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildModalOption(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Acceso Administrativo',
                subtitle: 'Portal exclusivo para administradores',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Acceso Administrador seleccionado'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
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
      appBar: CustomAppBar(
        selectedIndex: _selectedIndex,
        isLoggedIn: isLoggedIn,
        onTabSelected: _onTabSelected,
        onLoginPressed: _showLoginOptionsModal,
        onRegisterPressed: _showRegisterOptionsModal,
        onLogoutPressed: () async {
          await supabase.auth.signOut();
        },
      ),
      drawer: const CustomDrawer(),
      body: Stack(
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
                    color: AppTheme.primaryGreen.withValues(alpha: 0.22),
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
    );
  }
}
