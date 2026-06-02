import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../models/user_profile.dart';
import '../services/database_helper.dart';
import '../main.dart' show DashboardPage;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // Controladores de texto
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicationController = TextEditingController();

  // Estado del formulario
  String? _selectedSex;
  bool _hasFamilyHistory = false;
  bool _hasTremor = false;
  bool _takingMedication = false;

  int _currentPage = 0;
  bool _isSaving = false;

  // Calculado dinámicamente
  int get _age => int.tryParse(_ageController.text) ?? 0;
  bool get _isSenior =>
      (_selectedSex == 'male' && _age >= 60) ||
      (_selectedSex == 'female' && _age >= 65);
  bool get _isYoung => _age > 0 && _age < 40;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // Validar sólo los campos de la primera página
      if (_nameController.text.trim().isEmpty) {
        _showError('Por favor ingresa tu nombre');
        return;
      }
      if (_selectedSex == null) {
        _showError('Por favor selecciona tu sexo');
        return;
      }
      if (_ageController.text.isEmpty || _age < 5 || _age > 120) {
        _showError('Por favor ingresa una edad válida');
        return;
      }
    }

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        sex: _selectedSex!,
        age: _age,
        height: double.tryParse(_heightController.text),
        weight: double.tryParse(_weightController.text),
        hasFamilyHistory: _hasFamilyHistory,
        hasTremor: _hasTremor,
        takingMedication: _takingMedication,
        medicationNotes: _takingMedication ? _medicationController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertUserProfile(profile);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error al guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────
            _buildHeader(colors),

            // ── Indicador de paso ───────────────────────
            _buildStepIndicator(colors),

            // ── Páginas ─────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _PageOne(
                    nameController: _nameController,
                    ageController: _ageController,
                    selectedSex: _selectedSex,
                    onSexChanged: (v) => setState(() => _selectedSex = v),
                    onAgeChanged: (_) => setState(() {}),
                  ),
                  _PageTwo(
                    heightController: _heightController,
                    weightController: _weightController,
                    isSenior: _isSenior,
                    isYoung: _isYoung,
                    sex: _selectedSex ?? 'male',
                    age: _age,
                  ),
                  _PageThree(
                    hasFamilyHistory: _hasFamilyHistory,
                    hasTremor: _hasTremor,
                    takingMedication: _takingMedication,
                    medicationController: _medicationController,
                    isSenior: _isSenior,
                    onFamilyHistoryChanged: (v) =>
                        setState(() => _hasFamilyHistory = v),
                    onTremorChanged: (v) => setState(() => _hasTremor = v),
                    onMedicationChanged: (v) =>
                        setState(() => _takingMedication = v),
                  ),
                ],
              ),
            ),

            // ── Botones de navegación ────────────────────
            _buildNavButtons(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: FadeInDown(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.health_and_safety,
                  color: colors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parkinson Detector',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Configuración inicial',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colors) {
    const labels = ['Personal', 'Físico', 'Clínico'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = i == _currentPage;
          final isDone = i < _currentPage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDone || isActive
                          ? colors.primary
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavButtons(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevPage,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Atrás'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _isSaving
                  ? null
                  : (_currentPage < 2 ? _nextPage : _saveProfile),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _currentPage < 2 ? 'Continuar' : 'Comenzar',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// PÁGINA 1 — Datos personales (nombre, sexo, edad)
// ══════════════════════════════════════════════════════
class _PageOne extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final String? selectedSex;
  final ValueChanged<String?> onSexChanged;
  final ValueChanged<String> onAgeChanged;

  const _PageOne({
    required this.nameController,
    required this.ageController,
    required this.selectedSex,
    required this.onSexChanged,
    required this.onAgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuéntanos sobre ti',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta información nos ayuda a personalizar los umbrales de análisis.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),

            // Nombre
            _label('Nombre completo'),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDeco(
                context,
                hint: 'Ej. María García',
                icon: Icons.person_outline,
              ),
            ),

            const SizedBox(height: 20),

            // Sexo biológico
            _label('Sexo biológico'),
            const SizedBox(height: 8),
            _InfoChip(
              message:
                  'El sexo biológico influye en la edad de inicio y los patrones de síntomas del Parkinson.',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SexCard(
                    label: 'Hombre',
                    icon: Icons.male,
                    value: 'male',
                    selected: selectedSex == 'male',
                    onTap: () => onSexChanged('male'),
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SexCard(
                    label: 'Mujer',
                    icon: Icons.female,
                    value: 'female',
                    selected: selectedSex == 'female',
                    onTap: () => onSexChanged('female'),
                    color: const Color(0xFFEC4899),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Edad
            _label('Edad'),
            const SizedBox(height: 8),
            TextFormField(
              controller: ageController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              onChanged: onAgeChanged,
              decoration: _inputDeco(
                context,
                hint: 'Ej. 65',
                icon: Icons.cake_outlined,
                suffix: 'años',
              ),
            ),

            const SizedBox(height: 12),
            _AgeContextCard(ageText: ageController.text, sex: selectedSex),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// PÁGINA 2 — Datos físicos (talla, peso)
// Campos adicionales según grupo de riesgo
// ══════════════════════════════════════════════════════
class _PageTwo extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;
  final bool isSenior;
  final bool isYoung;
  final String sex;
  final int age;

  const _PageTwo({
    required this.heightController,
    required this.weightController,
    required this.isSenior,
    required this.isYoung,
    required this.sex,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Datos físicos',
              style: GoogleFonts.inter(
                  fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Opcionales, pero mejoran la precisión del análisis.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Banner según grupo
            if (isSenior)
              _RiskBanner(
                icon: Icons.elderly,
                color: Colors.orange,
                message:
                    'Perfil de adulto mayor: usaremos umbrales ajustados para tu grupo de edad, donde el Parkinson es más prevalente.',
              )
            else if (isYoung)
              _RiskBanner(
                icon: Icons.directions_run,
                color: Colors.blue,
                message:
                    'Perfil joven (<40 años): aplicaremos parámetros de Parkinson de inicio temprano, que difieren en presentación.',
              )
            else
              _RiskBanner(
                icon: Icons.info_outline,
                color: Colors.green,
                message:
                    'Perfil adulto: usaremos los umbrales estándar de detección.',
              ),

            const SizedBox(height: 20),

            // Estatura
            _label('Estatura (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco(
                context,
                hint: 'Ej. 165',
                icon: Icons.height,
                suffix: 'cm',
              ),
            ),

            const SizedBox(height: 20),

            // Peso
            _label('Peso (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco(
                context,
                hint: 'Ej. 70',
                icon: Icons.monitor_weight_outlined,
                suffix: 'kg',
              ),
            ),

            // Datos adicionales para adultos mayores
            if (isSenior) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Para tu grupo de edad',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sex == 'male'
                          ? 'Los hombres ≥60 años tienen 2-3× más riesgo. Los tests se calibrarán con mayor sensibilidad para temblor en reposo, bradicinesia y rigidez.'
                          : 'Las mujeres ≥65 años presentan Parkinson con más frecuencia que antes. Se ajustarán los umbrales de voz y marcha según tu grupo.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.orange.shade900),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// PÁGINA 3 — Historial clínico
// ══════════════════════════════════════════════════════
class _PageThree extends StatelessWidget {
  final bool hasFamilyHistory;
  final bool hasTremor;
  final bool takingMedication;
  final TextEditingController medicationController;
  final bool isSenior;
  final ValueChanged<bool> onFamilyHistoryChanged;
  final ValueChanged<bool> onTremorChanged;
  final ValueChanged<bool> onMedicationChanged;

  const _PageThree({
    required this.hasFamilyHistory,
    required this.hasTremor,
    required this.takingMedication,
    required this.medicationController,
    required this.isSenior,
    required this.onFamilyHistoryChanged,
    required this.onTremorChanged,
    required this.onMedicationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial clínico',
              style: GoogleFonts.inter(
                  fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta información ajusta la sensibilidad de los tests.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Antecedentes familiares
            _ClinicalToggle(
              icon: Icons.family_restroom,
              color: const Color(0xFF8B5CF6),
              title: 'Antecedentes familiares',
              subtitle:
                  '¿Algún familiar directo fue diagnosticado con Parkinson?',
              value: hasFamilyHistory,
              onChanged: onFamilyHistoryChanged,
            ),

            const SizedBox(height: 12),

            // Temblor previo
            _ClinicalToggle(
              icon: Icons.vibration,
              color: const Color(0xFFEF4444),
              title: 'Temblor previo',
              subtitle:
                  '¿Has notado temblor en manos u otras partes del cuerpo?',
              value: hasTremor,
              onChanged: onTremorChanged,
            ),

            const SizedBox(height: 12),

            // Medicación
            _ClinicalToggle(
              icon: Icons.medication_outlined,
              color: const Color(0xFF10B981),
              title: 'Medicación actual',
              subtitle:
                  '¿Tomas medicamentos que puedan afectar el movimiento o el sistema nervioso?',
              value: takingMedication,
              onChanged: onMedicationChanged,
            ),

            if (takingMedication) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: medicationController,
                maxLines: 2,
                decoration: _inputDeco(
                  context,
                  hint: 'Ej. Levodopa, antipsicóticos…',
                  icon: Icons.notes_outlined,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Nota final
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline,
                      color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu información se guarda únicamente en este dispositivo y nunca se comparte.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// WIDGETS DE SOPORTE
// ══════════════════════════════════════════════════════

class _SexCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _SexCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgeContextCard extends StatelessWidget {
  final String ageText;
  final String? sex;

  const _AgeContextCard({required this.ageText, required this.sex});

  @override
  Widget build(BuildContext context) {
    final age = int.tryParse(ageText) ?? 0;
    if (age == 0) return const SizedBox.shrink();

    String message;
    Color color;
    IconData icon;

    final isSenior =
        (sex == 'male' && age >= 60) || (sex == 'female' && age >= 65);

    if (age < 40) {
      message =
          'Perfil joven: evaluaremos patrones de Parkinson de inicio temprano.';
      color = Colors.blue;
      icon = Icons.directions_run;
    } else if (isSenior) {
      message =
          'Adulto mayor: grupo de mayor prevalencia. Los tests tendrán mayor sensibilidad.';
      color = Colors.orange;
      icon = Icons.elderly;
    } else {
      message = 'Adulto: se usarán umbrales estándar de detección.';
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: color.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _RiskBanner({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 13, color: color.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicalToggle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ClinicalToggle({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.07) : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? color.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
              fontSize: 12, color: colors.onSurfaceVariant),
        ),
        trailing: Switch(
          value: value,
          activeColor: color,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String message;
  const _InfoChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
                fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────
Widget _label(String text) {
  return Text(
    text,
    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
  );
}

InputDecoration _inputDeco(
  BuildContext context, {
  required String hint,
  required IconData icon,
  String? suffix,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    suffixText: suffix,
    filled: true,
    fillColor: colors.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.primary, width: 2),
    ),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
