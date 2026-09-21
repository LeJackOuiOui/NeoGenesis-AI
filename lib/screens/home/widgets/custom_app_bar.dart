import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool isLoggedIn;
  final Function(int) onTabSelected;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;
  final VoidCallback onLogoutPressed;

  const CustomAppBar({
    super.key,
    required this.selectedIndex,
    required this.isLoggedIn,
    required this.onTabSelected,
    required this.onLoginPressed,
    required this.onRegisterPressed,
    required this.onLogoutPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.textDark,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          return Row(
            children: [
              // LOGO Y TÍTULO
              _buildBrand(),

              const Spacer(),

              if (isCompact)
                _buildCompactMenu(context)
              else ...[
                if (isLoggedIn) ...[
                  // ITEMS DE NAVEGACIÓN (Solo visibles si se ha iniciado sesión)
                  _buildNavItem('Inicio', 0),
                  const SizedBox(width: 20),
                  _buildNavItem('Registros', 1),
                  const SizedBox(width: 20),
                  _buildNavItem('Perfil', 2),
                  const SizedBox(width: 28),

                  // BOTÓN DE CERRAR SESIÓN
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    onPressed: onLogoutPressed,
                  ),
                ] else ...[
                  // BOTONES DE AUTENTICACIÓN (Solo visibles si NO se ha iniciado sesión)
                  ElevatedButton.icon(
                    onPressed: onRegisterPressed,
                    style: _authButtonStyle(),
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text(
                      'Registrarse',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onLoginPressed,
                    style: _authButtonStyle(),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        Image.asset(
          'assets/images/logo_neogenesis.png',
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: 'NEOGENESIS '),
              TextSpan(
                text: 'IA',
                style: TextStyle(color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ButtonStyle _authButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
    );
  }

  Widget _buildCompactMenu(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Abrir menú',
      color: AppTheme.textDark,
      icon: const Icon(Icons.menu, color: Colors.white),
      onSelected: (value) {
        switch (value) {
          case 'inicio':
            onTabSelected(0);
          case 'registros':
            onTabSelected(1);
          case 'perfil':
            onTabSelected(2);
          case 'logout':
            onLogoutPressed();
          case 'registro':
            onRegisterPressed();
          case 'login':
            onLoginPressed();
        }
      },
      itemBuilder: (context) {
        if (isLoggedIn) {
          return const [
            PopupMenuItem(
              value: 'inicio',
              child: Text('Inicio', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'registros',
              child: Text('Registros', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'perfil',
              child: Text('Perfil', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ];
        } else {
          return const [
            PopupMenuItem(
              value: 'registro',
              child: Text('Registrarse', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'login',
              child: Text(
                'Iniciar sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ];
        }
      },
    );
  }

  Widget _buildNavItem(String title, int index) {
    final bool isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(height: 2, width: 20, color: AppTheme.primaryGreen),
        ],
      ),
    );
  }
}
