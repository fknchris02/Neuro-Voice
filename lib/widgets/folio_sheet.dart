import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/database_helper.dart';
import '../services/parkinson_api.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Pide el folio de evaluación, lo valida con el servidor y guarda al
/// paciente como perfil local. Devuelve true si quedó vinculado.
Future<bool> showFolioSheet(BuildContext context) async {
  final linked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FolioSheet(),
  );
  return linked ?? false;
}

class _FolioSheet extends StatefulWidget {
  const _FolioSheet();

  @override
  State<_FolioSheet> createState() => _FolioSheetState();
}

class _FolioSheetState extends State<_FolioSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final folio = normalizeFolio(_controller.text);
    if (!folioPattern.hasMatch(folio)) {
      setState(() => _error = 'Revisa el folio: debe verse como CM26-9HTK57.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ParkinsonApi.linkPatient(folio);
      if (!mounted) return;
      await DatabaseHelper.instance.replaceUserProfile(profile);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('No se pudo guardar tu folio. Inténtalo de nuevo.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: scheme.primaryFixed,
                child: Icon(Icons.badge_outlined, color: scheme.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ingresa tu folio de evaluación',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Te lo entrega tu médico al darte de alta.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_loading,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              textAlign: TextAlign.center,
              inputFormatters: [_FolioFormatter()],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: 'CM26-XXXXXX',
                errorText: _error,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mayúsculas y guion automáticos mientras se escribe el folio.
class _FolioFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalizeFolio(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
