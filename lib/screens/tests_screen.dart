import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/neuro_app_bar.dart';
import 'tests/spiral_test_screen.dart';
import 'tests/voice_test_screen.dart';

class TestsPage extends StatelessWidget {
  const TestsPage({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NeuroAppBar(title: 'Pruebas clínicas'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _TestListItem(
            icon: Icons.mic_none,
            title: 'Prueba de voz',
            subtitle: 'Estabilidad y claridad de la voz · 3 × 5 s',
            color: AppColors.primary,
            onTap: () => _open(context, const VoiceTestScreen()),
          ),
          const SizedBox(height: 12),
          _TestListItem(
            icon: Icons.draw_outlined,
            title: 'Test de espiral',
            subtitle: 'Temblor y precisión motora',
            color: const Color(0xFF3B82F6),
            onTap: () => _open(context, const SpiralTestScreen()),
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
  final VoidCallback onTap;

  const _TestListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
