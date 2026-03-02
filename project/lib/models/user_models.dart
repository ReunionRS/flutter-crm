class AppUser {
  const AppUser({
    required this.id,
    required this.fio,
    required this.email,
    required this.role,
    this.isActive = true,
    this.isArchived = false,
  });

  final String id;
  final String fio;
  final String email;
  final String role;
  final bool isActive;
  final bool isArchived;

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? '').toString(),
      fio: (json['fio'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'client').toString(),
      isActive: json['isActive'] == false ? false : true,
      isArchived: json['isArchived'] == true,
    );
  }
}
