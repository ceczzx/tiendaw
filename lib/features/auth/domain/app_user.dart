enum UserRole { admin, seller }

class AppUser {
  const AppUser({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final UserRole role;

  AppUser copyWith({String? id, String? name, UserRole? role}) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
