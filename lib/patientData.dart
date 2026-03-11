class PatientData {
  final String name;
  final String dob;
  final String age;
  final String gender;
  final String height;
  final String weight;
  final String bloodType;
  final String conditions;

  const PatientData({
    required this.name,
    required this.dob,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.bloodType,
    required this.conditions,
  });

  Map<String, String> toMap() => {
    'name': name,
    'dob': dob,
    'age': age,
    'gender': gender,
    'height': '$height cm',
    'weight': '$weight kg',
    'bloodType': bloodType,
    'conditions': conditions.isEmpty ? 'None' : conditions,
  };
}