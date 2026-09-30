import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../theme/app_theme.dart';

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
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(Icons.mic, color: Colors.white, size: size * 0.6),
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
          ? Icon(Icons.person, size: widget.radius, color: scheme.primary)
          : Text(
              initials,
              style: TextStyle(
                fontSize: widget.radius * 0.75,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
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
      titleSpacing: canPop ? 0 : AppSpacing.margin,
      leading: canPop
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
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
