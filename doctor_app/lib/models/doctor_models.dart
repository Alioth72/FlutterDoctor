class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String hospital;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
  });
}

class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
  });
}
