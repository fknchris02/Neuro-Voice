import 'package:flutter/material.dart';

import '../config/clinical_supervisor.dart';
import '../models/voice_prediction.dart';
import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';
import '../utils/formatters.dart';
import 'neuro_app_bar.dart';
import 'supervisor_card.dart';

// --- Widgets de la pantalla de Inicio (design/stitch/inicio) ---

class GreetingHeader extends StatelessWidget {
  final String userName;

  const GreetingHeader({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = initialsOf(userName);

    return Row(
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppShadows.small,
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryFixed,
            child: initials.isEmpty
                ? Icon(Icons.person, color: scheme.primary)
                : Text(
                    initials,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BIENVENIDO DE NUEVO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.secondary,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                userName.trim().isEmpty
                    ? greetingForTime()
                    : '${greetingForTime()}, $userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner "Último Índice de Estabilidad Vocal" con el resultado real.
/// El índice es 100 − probabilidad estimada.
class StabilityBanner extends StatelessWidget {
  final VoicePrediction? prediction;
  final DateTime? timestamp;
  final VoidCallback? onTap;

  const StabilityBanner({
    super.key,
    required this.prediction,
    required this.timestamp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = prediction;
    final risk = p?.risk;

    return SoftCard(
      onTap: p == null ? null : onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primaryFixed,
            child: Icon(Icons.health_and_safety, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Último Índice de Estabilidad Vocal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      p == null
                          ? '—'
                          : '${(100 - p.probability).clamp(0, 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: risk?.color.withValues(alpha: 0.12) ??
                            scheme.tertiaryFixed,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        risk?.label ?? 'Sin evaluaciones',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: risk?.color ?? scheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p == null ? 'Aún no' : 'Última prueba',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                timestamp == null ? 'hay datos' : formatRelativeDateTime(timestamp!),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chips de filtro horizontales.
class TestFilterChips extends StatelessWidget {
  final List<String> categories;
  final int selected;
  final int totalCount;
  final ValueChanged<int> onSelected;

  const TestFilterChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.totalCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = Glass.isDark(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Sangrado hasta el borde, como en el diseño (-mx-margin px-margin).
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.margin, 4, AppSpacing.margin, 10),
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Semantics(
                selected: i == selected,
                button: true,
                child: PressableScale(
                  scale: 0.94,
                  // El chip elegido se vuelve carmesí con un fundido suave.
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: Colors.white.withValues(
                            alpha: i == selected ? 0.35 : (dark ? 0.14 : 0.9),
                          ),
                        ),
                      ),
                      gradient:
                          i == selected ? Glass.crimson : Glass.fill(context),
                      shadows: i == selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : Glass.shadow(context, depth: 0.25),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => onSelected(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: theme.textTheme.labelMedium!.copyWith(
                                  color: i == selected
                                      ? Colors.white
                                      : scheme.onSurfaceVariant,
                                ),
                                child: Text(categories[i]),
                              ),
                              if (i == 0 && i == selected) ...[
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.25),
                                  child: Text(
                                    '$totalCount',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HeroTestCard extends StatelessWidget {
  final String title;
  final String description;
  final String duration;
  final VoidCallback onTap;
  final ClinicalSupervisor supervisor;

  const HeroTestCard({
    super.key,
    required this.title,
    required this.description,
    required this.duration,
    required this.onTap,
    this.supervisor = assignedSupervisor,
  });

  static const _bars = [
    (12.0, false), (20.0, false), (32.0, true), (24.0, false), (16.0, false),
    (28.0, true), (36.0, true), (20.0, false), (16.0, false), (32.0, true),
    (24.0, false), (12.0, false), (28.0, true), (36.0, true), (20.0, false),
    (12.0, false), (24.0, false), (32.0, true), (16.0, false), (8.0, false),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onPrimary = Colors.white;

    return Semantics(
      button: true,
      label: 'Comenzar $title',
      excludeSemantics: true,
      child: PressableScale(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB8202F),
                AppColors.primaryContainer,
                AppColors.primary,
              ],
              stops: [0, 0.5, 1],
            ),
            boxShadow: AppShadows.hero(AppColors.primaryContainer),
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter:
                            GlassRimPainter(radius: AppRadius.xl, strength: 0.55),
                      ),
                    ),
                  ),
                  // Círculos acústicos tenues de fondo.
                  const Positioned(
                    right: -32,
                    top: -16,
                    child: Opacity(opacity: 0.1, child: _Rings(size: 192)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: onPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              child: const Icon(Icons.mic_none, color: onPrimary, size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PRIORITARIA DEL DÍA',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.onPrimaryContainer,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'Duración: $duration',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: AppColors.primaryFixed),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryFixed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onPrimary.withValues(alpha: 0.8),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Mini visualizador de onda (decorativo).
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final (h, bright) in _bars)
                                Container(
                                  width: 4,
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: bright ? onPrimary : AppColors.primaryFixed,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primaryContainer, width: 2),
                              ),
                              child: SupervisorAvatar(
                                supervisor: supervisor,
                                radius: 16,
                                background: AppColors.secondary,
                                foreground: onPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    supervisor.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Médico supervisor',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: onPrimary.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.primaryContainer,
                                size: 30,
                              ),
                            ),
                          ],
                        ),
                      ],
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
}

class _Rings extends StatelessWidget {
  final double size;

  const _Rings({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
            ),
          ),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 6),
            ),
          ),
          Container(
            width: size * 0.25,
            height: size * 0.25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dato con ícono pequeño bajo la descripción de una prueba.
class TestMeta {
  final IconData icon;
  final String text;
  final bool highlight;

  const TestMeta(this.icon, this.text, {this.highlight = false});
}

/// Tarjeta blanca secundaria de prueba.
class SecondaryTestCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? tag;
  final String description;
  final List<TestMeta> meta;
  final bool comingSoon;
  final VoidCallback onTap;

  const SecondaryTestCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.tag,
    required this.description,
    required this.meta,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: comingSoon ? '$title, próximamente' : title,
      excludeSemantics: true,
      child: SoftCard(
        padding: const EdgeInsets.all(20),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      if (tag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryFixed,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            tag!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final m in meta)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon, size: 16, color: scheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              m.text,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: m.highlight
                                    ? scheme.secondary
                                    : scheme.onSurfaceVariant,
                                fontWeight:
                                    m.highlight ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Próximamente',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: scheme.surfaceContainerHigh,
                child: Icon(Icons.arrow_forward,
                    size: 20, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class ClinicalRecommendation extends StatelessWidget {
  final String title;
  final String text;

  const ClinicalRecommendation({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GlassCard(
      shadows: Glass.shadow(context, depth: 0.4),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
