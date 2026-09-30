import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import '../services/database_helper.dart';
import '../theme/liquid_glass.dart';
import '../widgets/folio_sheet.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// Si el teléfono aún no tiene un folio vinculado, lo pide primero.
  Future<void> _startEvaluation() async {
    final profile =
        await DatabaseHelper.instance.getUserProfile().catchError((_) => null);
    if (!mounted) return;
    if (profile?.folio == null) {
      final linked = await showFolioSheet(context);
      if (!linked || !mounted) return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
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
                
                // Logo; se encoge en pantallas pequeñas para no desbordar.
                Expanded(
                  child: Center(
                    child: ZoomIn(
                      duration: const Duration(milliseconds: 700),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: const AspectRatio(
                          aspectRatio: 1,
                          child: _SplashLogo(),
                        ),
                      ),
                    ),
                  ),
                ),
                
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
                        // Se hunde un poco al tocarlo y rebota al soltar.
                        child: PressableScale(
                          child: GestureDetector(
                            onTap: _startEvaluation,
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
                                          child: Text(
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

/// Logo de NeuroVoice con los bordes difuminados para que su fondo oscuro
/// se funda con el degradado de la bienvenida.
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const RadialGradient(
        radius: 0.5,
        colors: [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 0.84, 1],
      ).createShader(bounds),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'NeuroVoice',
      ),
    );
  }
}
