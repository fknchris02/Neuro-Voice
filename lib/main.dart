import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'screens/tests/spiral_test_screen.dart';
import 'screens/tests/voice_test_screen.dart';
import 'screens/tests/gait_test_screen.dart';
import 'screens/tests/tapping_test_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkinson Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      // Cambiamos el home al SplashScreen
      home: const SplashScreen(),
    );
  }
}

// NUEVO: Splash Screen con animación
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Configurar animación
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Iniciar animación
    _controller.forward();

    // Navegar al Dashboard después de 3 segundos
    _navigateToDashboard();
  }

  void _navigateToDashboard() {
    Future.delayed(const Duration(seconds: 6), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6366F1), // Color principal de tu app
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado - Puedes reemplazar con tu imagen
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.health_and_safety,
                    size: 60,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 30),

                // Texto con animación escalonada
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: Text(
                    'Parkinson Detector',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Subtítulo
                FadeInUp(
                  duration: const Duration(milliseconds: 1200),
                  child: Text(
                    'Monitoreo inteligente de salud',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Indicador de carga animado
                FadeInUp(
                  duration: const Duration(milliseconds: 1400),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                      strokeWidth: 3,
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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const TestsPage(),
    const HistoryPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Tests',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: const Text('Detección Parkinson'),
            ),
            actions: [
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta de estado general con animación
                  FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.health_and_safety,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Estado General',
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Bajo Riesgo',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            CircularPercentIndicator(
                              radius: 40.0,
                              lineWidth: 8.0,
                              percent: 0.85,
                              center: Text(
                                "85%",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              progressColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              circularStrokeCap: CircularStrokeCap.round,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Última evaluación: Hace 2 días',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tests disponibles
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tests Disponibles',
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '4 disponibles',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid de tests con animaciones escalonadas
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      FadeInUp(
                        duration: const Duration(milliseconds: 700),
                        child: _EnhancedTestCard(
                          icon: Icons.draw,
                          title: 'Test de Espiral',
                          description: 'Análisis de temblor',
                          color: const Color(0xFF3B82F6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SpiralTestScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 800),
                        child: _EnhancedTestCard(
                          icon: Icons.voice_chat,
                          title: 'Test de Voz',
                          description: 'Análisis vocal',
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const VoiceTestScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 900),
                        child: _EnhancedTestCard(
                          icon: Icons.directions_walk,
                          title: 'Test de Marcha',
                          description: 'Análisis de movimiento',
                          color: const Color(0xFF10B981),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GaitTestScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: _EnhancedTestCard(
                          icon: Icons.touch_app,
                          title: 'Test de Tapping',
                          description: 'Coordinación motora',
                          color: const Color(0xFFF59E0B),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TappingTestScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Gráfico de progreso
                  FadeInUp(
                    duration: const Duration(milliseconds: 1100),
                    child: Text(
                      'Progreso Semanal',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1200),
                    child: _ProgressChart(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnhancedTestCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _EnhancedTestCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  State<_EnhancedTestCard> createState() => _EnhancedTestCardState();
}

class _EnhancedTestCardState extends State<_EnhancedTestCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..scale(_isHovered ? 0.95 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color,
                widget.color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
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

class _ProgressChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                  if (value.toInt() >= 0 && value.toInt() < days.length) {
                    return Text(
                      days[value.toInt()],
                      style: GoogleFonts.inter(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 75),
                const FlSpot(1, 80),
                const FlSpot(2, 78),
                const FlSpot(3, 85),
                const FlSpot(4, 82),
                const FlSpot(5, 88),
                const FlSpot(6, 85),
              ],
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 4,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Clases restantes (TestsPage, HistoryPage, ProfilePage) sin cambios
class TestsPage extends StatelessWidget {
  const TestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tests Clínicos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TestListItem(
            icon: Icons.draw,
            title: 'Test de Espiral',
            subtitle: 'Evalúa temblor y precisión motora',
            color: const Color(0xFF3B82F6),
            lastTest: 'Hace 2 días',
            score: 85,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpiralTestScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String lastTest;
  final int score;
  final VoidCallback onTap;

  const _TestListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lastTest,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text('Evaluación ${10 - index}'),
              subtitle: Text('${index + 1} días atrás'),
              trailing: Chip(
                label: Text('${85 + math.Random().nextInt(15)}/100'),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Usuario', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('usuario@email.com', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}