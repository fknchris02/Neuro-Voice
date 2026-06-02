class UserProfile {
  final int? id;
  final String name;
  final String sex; // 'male', 'female'
  final int age;
  final double? height; // cm
  final double? weight; // kg
  final bool hasFamilyHistory; // antecedentes familiares de Parkinson
  final bool hasTremor; // temblor previo reportado
  final bool takingMedication; // medicamentos actuales
  final String? medicationNotes;
  final DateTime createdAt;

  UserProfile({
    this.id,
    required this.name,
    required this.sex,
    required this.age,
    this.height,
    this.weight,
    required this.hasFamilyHistory,
    required this.hasTremor,
    required this.takingMedication,
    this.medicationNotes,
    required this.createdAt,
  });

  /// Grupo de riesgo basado en edad y sexo.
  /// Hombres >60 y mujeres >65 entran en umbral de mayor riesgo.
  String get riskGroup {
    if (sex == 'male' && age >= 60) return 'high_risk';
    if (sex == 'female' && age >= 65) return 'high_risk';
    if (age >= 45) return 'moderate_risk';
    return 'low_risk';
  }

  /// Indica si aplican umbrales pediátricos/jóvenes (<40 años)
  bool get isYoung => age < 40;

  /// Indica si es adulto mayor
  bool get isSenior => (sex == 'male' && age >= 60) || (sex == 'female' && age >= 65);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sex': sex,
      'age': age,
      'height': height,
      'weight': weight,
      'hasFamilyHistory': hasFamilyHistory ? 1 : 0,
      'hasTremor': hasTremor ? 1 : 0,
      'takingMedication': takingMedication ? 1 : 0,
      'medicationNotes': medicationNotes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'],
      sex: map['sex'],
      age: map['age'],
      height: map['height'],
      weight: map['weight'],
      hasFamilyHistory: map['hasFamilyHistory'] == 1,
      hasTremor: map['hasTremor'] == 1,
      takingMedication: map['takingMedication'] == 1,
      medicationNotes: map['medicationNotes'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? sex,
    int? age,
    double? height,
    double? weight,
    bool? hasFamilyHistory,
    bool? hasTremor,
    bool? takingMedication,
    String? medicationNotes,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      sex: sex ?? this.sex,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      hasFamilyHistory: hasFamilyHistory ?? this.hasFamilyHistory,
      hasTremor: hasTremor ?? this.hasTremor,
      takingMedication: takingMedication ?? this.takingMedication,
      medicationNotes: medicationNotes ?? this.medicationNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
