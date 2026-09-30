/// Médico que habilita y supervisa las pruebas de voz del paciente.
class ClinicalSupervisor {
  final String name;
  final String specialty;

  const ClinicalSupervisor({required this.name, required this.specialty});

  /// Iniciales para el avatar, ignorando el tratamiento ("Dr.", "Dra.").
  String get initials {
    final parts = name
        .split(' ')
        .where((p) => p.isNotEmpty && !p.endsWith('.'))
        .toList();
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// Médico asignado actualmente. Reemplazar cuando exista el flujo de
/// asignación/acceso real desde el servidor.
const assignedSupervisor = ClinicalSupervisor(
  name: 'Dra. Elena Vancea',
  specialty: 'Especialista en Trastornos del Movimiento',
);
