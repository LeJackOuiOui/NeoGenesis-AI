import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';

class CustomSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final ValueChanged<int> onNavigationSelected;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onToggle;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;
  final VoidCallback onLogoutPressed;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.onNavigationSelected,
    required this.onHoverChanged,
    required this.onToggle,
    required this.onLoginPressed,
    required this.onRegisterPressed,
    required this.onLogoutPressed,
  });

  static const _items = [
    _SidebarItem(label: 'Inicio', icon: Icons.home_outlined),
    _SidebarItem(label: 'Registros', icon: Icons.assignment_outlined),
    _SidebarItem(label: 'Candidatos', icon: Icons.people_outline),
    _SidebarItem(label: 'Vacantes', icon: Icons.work_outline),
    _SidebarItem(label: 'Perfil', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final width = isExpanded ? 220.0 : 60.0;

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: ColoredBox(
          color: AppTheme.textDark,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 68,
                          child: isExpanded
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildLogo(),
                                        const SizedBox(width: 8),
                                        RichText(
                                          maxLines: 1,
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            children: [
                                              TextSpan(text: 'NEOGENESIS '),
                                              TextSpan(
                                                text: 'IA',
                                                style: TextStyle(
                                                  color: AppTheme.primaryGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Positioned(
                                      right: 4,
                                      child: IconButton(
                                        tooltip: 'Contraer menú',
                                        onPressed: onToggle,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.chevron_left_rounded,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Center(
                                  child: Tooltip(
                                    message: 'Expandir menú',
                                    child: InkWell(
                                      onTap: onToggle,
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildLogo(),
                                    ),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (var index = 0; index < _items.length; index++)
                          _buildNavigationItem(context, _items[index], index),
                        const Spacer(),
                        if (isExpanded) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: onLoginPressed,
                                icon: const Icon(Icons.login_rounded, size: 18),
                                label: const Text('Iniciar sesión'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: onRegisterPressed,
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 18,
                                ),
                                label: const Text('Registrarse'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: Center(
                              child: IconButton(
                                tooltip: 'Iniciar sesión',
                                onPressed: onLoginPressed,
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.login_rounded,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: Center(
                              child: IconButton(
                                tooltip: 'Registrarse',
                                onPressed: onRegisterPressed,
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: AppTheme.primaryGreen,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                        _buildLogoutButton(context),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo_Neogenesis.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.auto_awesome,
        color: AppTheme.primaryGreen,
        size: 30,
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    _SidebarItem item,
    int index,
  ) {
    final isSelected = selectedIndex == index;
    final foreground = isSelected ? Colors.white : Colors.white70;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 12 : 6,
        vertical: 3,
      ),
      child: Tooltip(
        message: isExpanded ? '' : item.label,
        child: Material(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onNavigationSelected(index),
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(item.icon, size: 19, color: foreground),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(child: Icon(item.icon, size: 20, color: foreground)),
                  if (isSelected && isExpanded)
                    Positioned(
                      left: 0,
                      top: 10,
                      bottom: 10,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 12 : 10),
      child: Tooltip(
        message: isExpanded ? '' : 'Cerrar sesión',
        child: InkWell(
          onTap: onLogoutPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (isExpanded) const SizedBox(width: 16),
                const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFE57373),
                  size: 18,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Color(0xFFE8A0A0), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;

  const _SidebarItem({required this.label, required this.icon});
}
