import 'dart:async';
import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../main.dart';
import '../../auth/login_modal.dart';
import '../../auth/register_modal.dart';

class CarouselWidget extends StatefulWidget {
  const CarouselWidget({super.key});

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  final List<Map<String, String>> _carouselItems = [
    {
      'image': 'assets/images/carrusel_1.jpeg',
      'title': 'Optimiza la Gestión Humana',
      'subtitle':
          'Potencia el desarrollo de tu equipo con herramientas inteligentes.',
    },
    {
      'image': 'assets/images/logo_neogenesis.png',
      'title': 'Nómina Autónoma y Precisa',
      'subtitle': 'Automatiza procesos complejos y reduce tiempos de cálculo.',
    },
    {
      'image': 'assets/images/carrusel_1.jpeg',
      'title': 'Toma de Decisiones con IA',
      'subtitle': 'Analíticas avanzadas en tiempo real para tu organización.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      _currentPage = (_currentPage + 1) % _carouselItems.length;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _nextPage() {
    if (_currentPage < _carouselItems.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        _carouselItems.length - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final carouselHeight = (constraints.maxWidth * 0.38).clamp(
          220.0,
          360.0,
        );

        return SizedBox(
          height: carouselHeight,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _carouselItems.length,
                itemBuilder: (context, index) {
                  return _buildCarouselItem(_carouselItems[index]);
                },
              ),
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: _previousPage,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    onPressed: _nextPage,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.transparent,
      ),
    );
  }

  Widget _buildCarouselItem(Map<String, String> item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              item['image']!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['subtitle']!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewInicio extends StatefulWidget {
  const ViewInicio({super.key});

  @override
  State<ViewInicio> createState() => _ViewInicioState();
}

class _ViewInicioState extends State<ViewInicio> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToSeccion() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        520,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // ==========================================
            // 1. SECCIÓN HERO (Banner Principal)
            // ==========================================
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDCEFE4), Color(0xFFEAF4ED)],
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 40.0,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                            children: [
                              TextSpan(text: 'NeoGenesis '),
                              TextSpan(
                                text: 'IA',
                                style: TextStyle(color: AppTheme.primaryGreen),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'El futuro de la gestión humana, más inteligente y eficiente.',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Automatiza, optimiza y transforma la forma en que las organizaciones gestionan su talento humano con el poder de la Inteligencia Artificial.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _comenzarGratis,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Comenzar gratis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // BOTÓN CONOCER MÁS
                            OutlinedButton(
                              onPressed: _scrollToSeccion,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryGreen,
                                side: const BorderSide(
                                  color: AppTheme.primaryGreen,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Conocer más',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Image.asset(
                    'assets/images/logo_neogenesis.png',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.auto_awesome,
                      size: 180,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // 2. SECCIÓN CARRUSEL INFORMATIVO
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: const CarouselWidget(),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ==========================================
            // 3. SECCIÓN SERVICIOS (Tarjetas)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                children: [
                  const Text(
                    'Nuestros Servicios',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Soluciones inteligentes diseñadas para optimizar la gestión de tu organización.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      double cardWidth = constraints.maxWidth > 800
                          ? (constraints.maxWidth - 48) / 4
                          : (constraints.maxWidth > 500
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth);

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildInfoCard(
                            width: cardWidth,
                            icon: Icons.people_outline,
                            title: 'Gestión de Empleados',
                            description:
                                'Administra la información y el rendimiento de tu equipo.',
                            rutaModulo: '/empleados',
                            features: [
                              'Expedientes digitales consolidados',
                              'Evaluaciones de desempeño automáticas',
                              'Seguimiento de asistencia e incidencias',
                            ],
                          ),
                          _buildInfoCard(
                            width: cardWidth,
                            icon: Icons.calculate_outlined,
                            title: 'Nómina Inteligente',
                            description:
                                'Simplifica el cálculo y control de la nómina de tu organización.',
                            rutaModulo: '/nomina',
                            features: [
                              'Cálculo automático de salarios',
                              'Control de deducciones y prestaciones',
                              'Reportes de nómina organizados',
                            ],
                          ),
                          _buildInfoCard(
                            width: cardWidth,
                            icon: Icons.analytics_outlined,
                            title: 'Análisis de Datos',
                            description:
                                'Convierte los datos de tu equipo en decisiones más oportunas.',
                            rutaModulo: '/analisis',
                            features: [
                              'Indicadores de gestión humana',
                              'Reportes visuales en tiempo real',
                              'Apoyo para la toma de decisiones',
                            ],
                          ),
                          _buildInfoCard(
                            width: cardWidth,
                            icon: Icons.security_outlined,
                            title: 'Seguridad y Permisos',
                            description:
                                'Protege la información y controla el acceso a cada módulo.',
                            rutaModulo: '/seguridad',
                            features: [
                              'Roles y permisos personalizados',
                              'Protección de datos sensibles',
                              'Control de actividad de usuarios',
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ==========================================
            // 4. SECCIÓN INFORMACIÓN DETALLADA (Reintegrada)
            // ==========================================
            Container(
              width: double.infinity,
              color: Color(0xFFEAF4ED),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 48.0,
              ),
              child: Column(
                children: [
                  const Text(
                    'Acerca de NeoGenesis IA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: Text(
                      'Esta plataforma está enfocada en revolucionar la forma en que el departamento de Talentos y Recursos Humanos gestiona el personal. Aquí puedes desplegar la descripción detallada del proyecto, objetivos principales, características técnicas o preguntas frecuentes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  void _comenzarGratis() {
    if (supabase.auth.currentUser != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya tienes una sesión activa en el panel principal.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      return;
    }

    showDialog(context: context, builder: (context) => const RegisterModal());
  }

  Widget _buildInfoCard({
    required double width,
    required IconData icon,
    required String title,
    required String description,
    required String rutaModulo,
    required List<String> features,
  }) {
    return InkWell(
      onTap: () => _mostrarDetalleServicio(
        context,
        title,
        icon,
        description,
        features,
        rutaModulo,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.lightGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  'Saber más',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleServicio(
    BuildContext screenContext,
    String titulo,
    IconData icono,
    String descripcion,
    List<String> caracteristicas,
    String rutaModulo,
  ) {
    showGeneralDialog(
      context: screenContext,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(
        screenContext,
      ).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreenBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icono,
                          color: AppTheme.primaryGreen,
                          size: 28,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descripcion,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Capacidades destacadas:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...caracteristicas.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.primaryGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final isAuthenticated =
                            supabase.auth.currentUser != null;
                        Navigator.of(context).pop();

                        if (isAuthenticated) {
                          ScaffoldMessenger.of(screenContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Módulo seleccionado: $titulo ($rutaModulo)',
                              ),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        } else {
                          showDialog(
                            context: screenContext,
                            builder: (context) => const LoginModal(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Explorar módulo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
