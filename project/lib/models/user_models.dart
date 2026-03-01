class AppUser {
  const AppUser({
    required this.id,
    required this.fio,
    required this.email,
    required this.role,
  });

  final String id;
  final String fio;
  final String email;
  final String role;

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? '').toString(),
      fio: (json['fio'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'client').toString(),
    );
  }
}
