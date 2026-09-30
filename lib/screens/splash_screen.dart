import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/database_helper.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = false;

  Future<void> _checkProfileAndNavigate() async {
    setState(() => _isLoading = true);
    try {
      final profile = await DatabaseHelper.instance.getUserProfile();
      if (!mounted) return;

      if (profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF5A0016), // Darker red/burgundy top
              Color(0xFF1F1A1B), // Neutral black bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                FadeInDown(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mic, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            const TextSpan(
                              text: 'NeuroVoice ',
                              children: [
                                TextSpan(
                                  text: 'AI',
                                  style: TextStyle(color: Color(0xFFFF4B6E)),
                                ),
                              ],
                            ),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'BIOMARCADORES DE VOZ',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Center Graphic (Custom Animated Paint to match mockup)
                const Center(
                  child: BrainWaveAnimation(),
                ),
                
                const Spacer(),
                
                // Badges
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBadge(
                        icon: Icons.circle,
                        iconColor: Colors.greenAccent,
                        iconSize: 10,
                        text: 'Precisión 96.8%',
                      ),
                      _buildBadge(
                        icon: Icons.access_time,
                        iconColor: Colors.white70,
                        iconSize: 14,
                        text: 'Tiempo 30s',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                FadeInUp(
                  delay: const Duration(milliseconds: 500),
                  child: Text(
                    'Tu Voz Revela la',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    'Salud de Tu Cerebro',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFF4B6E), // Bright pink/red
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Subtitle
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: Text(
                    'Detección temprana y seguimiento de patrones\nneuromotores mediante análisis acústico asistido por\nInteligencia Artificial.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Bottom Buttons
                FadeInUp(
                  delay: const Duration(milliseconds: 900),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isLoading ? null : _checkProfileAndNavigate,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 16.0),
                                        child: _isLoading 
                                          ? const SizedBox(
                                              width: 24, height: 24,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : Text(
                                              'Iniciar Evaluación',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                      ),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFF9E1B26),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class BrainWaveAnimation extends StatefulWidget {
  const BrainWaveAnimation({super.key});

  @override
  State<BrainWaveAnimation> createState() => _BrainWaveAnimationState();
}

class _BrainWaveAnimationState extends State<BrainWaveAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 240),
          painter: BrainWavePainter(_controller.value),
        );
      },
    );
  }
}

class BrainWavePainter extends CustomPainter {
  final double animationValue;

  BrainWavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Glow rojo de fondo
    final glowPaint = Paint()
      ..color = const Color(0xFFFF4B6E).withOpacity(0.05 + (animationValue * 0.1))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 150, height: 200),
      glowPaint,
    );

    // 2. Trazado del contorno (Silueta del cerebro/cabeza)
    final outlinePath = Path();
    outlinePath.moveTo(center.dx, size.height - 20); // Base inferior
    // Curva izquierda
    outlinePath.cubicTo(
      center.dx - 100, size.height - 50, // Punto de control inferior izquierdo
      center.dx - 100, 30,             // Punto de control superior izquierdo
      center.dx, 10,                   // Top center
    );
    // Curva derecha
    outlinePath.cubicTo(
      center.dx + 100, 30,             // Punto de control superior derecho
      center.dx + 100, size.height - 50, // Punto de control inferior derecho
      center.dx, size.height - 20,     // Base inferior
    );

    // Dibujar línea exterior sólida, suave
    final outerLinePaint = Paint()
      ..color = const Color(0xFFFF4B6E).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawPath(outlinePath, outerLinePaint);

    // Dibujar línea interior (un poco más pequeña) para simular la profundidad
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.85); // Reducir escala al 85% desde el centro
    canvas.translate(-center.dx, -center.dy);
    
    final innerLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawPath(outlinePath, innerLinePaint);
    canvas.restore();

    // 3. Onda de sonido / Latido en el centro
    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
      
    final wavePath = Path();
    // La onda va de arriba hacia abajo
    wavePath.moveTo(center.dx, 30);
    wavePath.lineTo(center.dx, center.dy - 60);
    wavePath.lineTo(center.dx - 25, center.dy - 30);
    wavePath.lineTo(center.dx + 30, center.dy - 10);
    wavePath.lineTo(center.dx - 35, center.dy + 15);
    wavePath.lineTo(center.dx + 25, center.dy + 35);
    wavePath.lineTo(center.dx, center.dy + 60);
    wavePath.lineTo(center.dx, size.height - 30);
    
    canvas.drawPath(wavePath, wavePaint);

    // 4. Puntos brillantes en los picos de la onda
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final dotGlowPaint = Paint()
      ..color = const Color(0xFFFF4B6E)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;

    // Lista de picos definidos en la onda
    final peaks = [
      Offset(center.dx, 30),
      Offset(center.dx - 25, center.dy - 30),
      Offset(center.dx + 30, center.dy - 10),
      Offset(center.dx - 35, center.dy + 15),
      Offset(center.dx + 25, center.dy + 35),
      Offset(center.dx, size.height - 30),
      // Puntos extra a los lados para simular la imagen
      Offset(center.dx - 65, center.dy - 20),
      Offset(center.dx + 65, center.dy + 20),
      Offset(center.dx, 10),
      Offset(center.dx, size.height - 20),
    ];

    for (var peak in peaks) {
      // Glow palpitante para los puntos
      canvas.drawCircle(peak, 5 + (animationValue * 3), dotGlowPaint);
      canvas.drawCircle(peak, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BrainWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
