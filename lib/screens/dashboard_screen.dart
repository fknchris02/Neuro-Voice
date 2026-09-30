import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'tests_screen.dart';
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
        0 => HomePage(onOpenProfile: () => _select(3)),
        1 => const TestsPage(),
        2 => const HistoryPage(),
        _ => const ProfilePage(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El contenido pasa por debajo de la barra flotante.
      extendBody: true,
      body: _page(),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: _selectedIndex,
        onSelected: _select,
      ),
    );
  }
}

/// Barra de navegación flotante en forma de píldora (design/stitch/inicio).
class FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.graphic_eq, Icons.graphic_eq, 'Pruebas'),
    (Icons.analytics_outlined, Icons.analytics, 'Historial'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 50,
                    offset: const Offset(0, 25),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _items.length; i++) _buildNavItem(context, i),
                ],
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
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onSelected(index),
        behavior: HitTestBehavior.opaque,
        // Área táctil mínima de 48 dp aunque el ícono sea más pequeño.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 56),
          // Los factores evitan que Center se expanda al alto de pantalla
          // que el Scaffold ofrece al bottomNavigationBar.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              padding: isSelected
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
                  : const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: isSelected ? AppShadows.small : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.7),
                    size: isSelected ? 20 : 22,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: labelStyle?.copyWith(color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
