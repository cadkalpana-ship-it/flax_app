class AppUser {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String name;

  // 'admin' | 'user'
  final String role;

  final bool isActive;
  final DateTime? dateJoined;

  AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.dateJoined,
  });

  bool get isAdmin {
    return role.trim().toLowerCase() == 'admin';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: (json['username'] as String?) ?? '',
      firstName: (json['first_name'] as String?) ?? '',
      lastName: (json['last_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
      isActive: (json['is_active'] as bool?) ?? true,
      dateJoined: json['date_joined'] != null
          ? DateTime.tryParse(
              json['date_joined'] as String,
            )
          : null,
    );
  }
}