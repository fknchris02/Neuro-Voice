import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../widgets/neuro_app_bar.dart';
import 'register_screen.dart';
import 'tests/database_viewer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseHelper.instance.getUserProfile();
    if (!mounted) return;
    setState(() {
      _profileData = profile != null
          ? {
              'name': profile.name,
              'sex': profile.sex == 'male' ? 'Hombre' : 'Mujer',
              'age': profile.age,
              'riskGroup': profile.riskGroup,
            }
          : null;
      _isLoading = false;
    });
  }

  Future<void> _resetProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cambiar perfil?'),
        content: const Text(
          'Se borrarán tus datos de registro y podrás ingresar un nuevo perfil. '
          'Tu historial de tests se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Sí, cambiar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await DatabaseHelper.instance.deleteUserProfile();

    if (!mounted) return;
    // Reemplaza toda la pila de navegación con el registro
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (route) => false,
    );
  }

  String _riskLabel(String? riskGroup) {
    switch (riskGroup) {
      case 'high_risk':
        return 'Alto riesgo';
      case 'moderate_risk':
        return 'Riesgo moderado';
      default:
        return 'Bajo riesgo';
    }
  }

  Color _riskColor(String? riskGroup) {
    switch (riskGroup) {
      case 'high_risk':
        return Colors.red;
      case 'moderate_risk':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NeuroAppBar(title: 'Perfil'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Espacio inferior para la barra de navegación flotante.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // ── Avatar + nombre ──────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profileData?['name'] ?? 'Usuario',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_profileData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _riskColor(_profileData!['riskGroup'])
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _riskColor(_profileData!['riskGroup'])
                                  .withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            _riskLabel(_profileData!['riskGroup']),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _riskColor(_profileData!['riskGroup']),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Datos básicos ────────────────────────
                if (_profileData != null)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.wc_outlined),
                          title: const Text('Sexo'),
                          trailing: Text(
                            _profileData!['sex'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cake_outlined),
                          title: const Text('Edad'),
                          trailing: Text(
                            '${_profileData!['age']} años',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Opciones ─────────────────────────────
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.medical_information_outlined),
                        title: const Text('Historial Médico'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notificaciones'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Configuración'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.storage),
                        title: const Text('Ver Base de Datos'),
                        subtitle: const Text('Información técnica'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DatabaseViewer(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('Ayuda y Soporte'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Acerca de'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Cambiar perfil (reseteo) ──────────────
                OutlinedButton.icon(
                  onPressed: _resetProfile,
                  icon: const Icon(Icons.switch_account_outlined),
                  label: const Text('Cambiar perfil'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.error),
                    padding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
