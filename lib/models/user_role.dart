enum UserRole {
  doctor,
  worker,
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.doctor:
        return 'Doctor Mode';
      case UserRole.worker:
        return 'Worker Mode';
      case UserRole.admin:
        return 'Admin Mode';
    }
  }

  String get description {
    switch (this) {
      case UserRole.doctor:
        return 'Access clinical records, prescriptions & patient care';
      case UserRole.worker:
        return 'Access shift monitoring, field visits & queue management';
      case UserRole.admin:
        return 'Access machine records, hospital inventory & system alerts';
    }
  }
}
