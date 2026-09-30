import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';

/// Marca de NeuroVoice: cuadro carmesí con micrófono.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: Glass.crimson,
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter:
              GlassRimPainter(radius: size * 0.32, strength: 0.6),
          child: Icon(Icons.mic_rounded, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}

String initialsOf(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0].toUpperCase())
    .join();

/// Avatar con las iniciales del paciente registrado.
class UserAvatar extends StatefulWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({super.key, this.radius = 16, this.onTap});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final p = await DatabaseHelper.instance.getUserProfile();
      if (mounted && p != null) setState(() => _name = p.name);
    } catch (_) {
      // Sin perfil disponible: se muestra el ícono genérico.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = initialsOf(_name);
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: scheme.primaryFixed,
      child: initials.isEmpty
          ? Icon(Icons.person,
              size: widget.radius, color: scheme.onPrimaryFixedVariant)
          : Text(
              initials,
              style: TextStyle(
                fontSize: widget.radius * 0.75,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryFixedVariant,
              ),
            ),
    );

    if (widget.onTap == null) return ExcludeSemantics(child: avatar);
    return IconButton(
      tooltip: 'Perfil',
      onPressed: widget.onTap,
      icon: avatar,
    );
  }
}

/// Barra superior de Stitch: volver + marca + título + avatar.
class NeuroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? overline;
  final List<Widget> actions;
  final VoidCallback? onAvatarTap;

  const NeuroAppBar({
    super.key,
    required this.title,
    this.overline,
    this.actions = const [],
    this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: canPop ? 4 : AppSpacing.margin,
      leading: canPop
          ? Center(
              child: SizedBox.square(
                dimension: 40,
                child: GlassCard(
                  radius: 20,
                  padding: EdgeInsets.zero,
                  shadows: Glass.shadow(context, depth: 0.4),
                  onTap: () => Navigator.maybePop(context),
                  child: Tooltip(
                    message: 'Volver',
                    child: Center(
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            )
          : null,
      title: Row(
        children: [
          BrandMark(size: canPop ? 28 : 32),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null)
                  Text(
                    overline!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ...actions,
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(child: UserAvatar(onTap: onAvatarTap)),
        ),
      ],
    );
  }
}
