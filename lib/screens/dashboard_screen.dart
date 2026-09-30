import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  void _select(int index) => setState(() => _selectedIndex = index);

  Widget _page() => switch (_selectedIndex) {
        0 => HomePage(onOpenProfile: () => _select(2)),
        1 => const HistoryPage(),
        _ => ProfilePage(onOpenHistory: () => _select(1)),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El contenido pasa por debajo de la barra flotante.
      extendBody: true,
      // Fundido cruzado entre pestañas: sale la actual y luego entra la nueva
      // con un leve zoom, sin que se encimen los dos contenidos.
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
        switchOutCurve: const Interval(0.45, 1, curve: Curves.easeInCubic),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _page()),
      ),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: _selectedIndex,
        onSelected: _select,
      ),
    );
  }
}

/// Barra de navegación flotante de cristal con una píldora carmesí que se
/// desliza hasta la pestaña elegida.
class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.analytics_outlined, Icons.analytics_rounded, 'Historial'),
    (Icons.person_outline, Icons.person_rounded, 'Perfil'),
  ];

  static const _height = 64.0;

  @override
  Widget build(BuildContext context) {
    final dark = Glass.isDark(context);
    final n = _items.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassCard(
              blur: true,
              radius: 99,
              padding: const EdgeInsets.all(5),
              shadows: [
                BoxShadow(
                  color: (dark ? Colors.black : AppColors.primary)
                      .withValues(alpha: dark ? 0.45 : 0.18),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
              child: SizedBox(
                height: _height - 10,
                child: Stack(
                  children: [
                    // Píldora que "fluye" entre pestañas.
                    AnimatedAlign(
                      alignment:
                          Alignment(-1 + 2 * selectedIndex / (n - 1), 0),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutBack,
                      child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: const DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: StadiumBorder(),
                            gradient: Glass.crimson,
                            shadows: [
                              BoxShadow(
                                color: Color(0x557A0014),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            foregroundPainter:
                                GlassRimPainter(radius: 99, strength: 0.55),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < n; i++)
                          Expanded(child: _buildNavItem(context, i)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final (icon, selectedIcon, label) = _items[index];
    final isSelected = selectedIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final color = isSelected ? Colors.white : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelected(index),
        behavior: HitTestBehavior.opaque,
        child: PressableScale(
          scale: 0.9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Icon(
                  isSelected ? selectedIcon : icon,
                  key: ValueKey(isSelected),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                child: Text(label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
