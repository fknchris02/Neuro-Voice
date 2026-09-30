import 'package:flutter/material.dart';

import '../config/clinical_supervisor.dart';
import '../theme/app_theme.dart';

class SupervisorAvatar extends StatelessWidget {
  final ClinicalSupervisor supervisor;
  final double radius;
  final Color? background;
  final Color? foreground;

  const SupervisorAvatar({
    super.key,
    this.supervisor = assignedSupervisor,
    this.radius = 22,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? scheme.primaryFixed,
      child: Text(
        supervisor.initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w800,
          // Contrasta con primaryFixed en modo claro y oscuro.
          color: foreground ?? scheme.onPrimaryFixedVariant,
        ),
      ),
    );
  }
}

/// Tarjeta del médico que habilita y supervisa la prueba (estilo Stitch).
class SupervisorCard extends StatelessWidget {
  final ClinicalSupervisor supervisor;

  /// Texto superior en mayúsculas (p. ej. "SUPERVISIÓN CLÍNICA").
  final String? caption;

  /// Línea inferior de estado, en color secundario.
  final String? status;
  final double avatarRadius;
  final bool verified;
  final Widget? trailing;

  const SupervisorCard({
    super.key,
    this.supervisor = assignedSupervisor,
    this.caption,
    this.status,
    this.avatarRadius = 22,
    this.verified = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SoftCard(
      child: Row(
        children: [
          SupervisorAvatar(supervisor: supervisor, radius: avatarRadius),
          SizedBox(width: avatarRadius > 24 ? AppSpacing.md : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null)
                  Text(
                    caption!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        supervisor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, size: 16, color: scheme.primary),
                    ],
                  ],
                ),
                Text(
                  supervisor.specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (status != null)
                  Text(
                    status!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.secondary),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
