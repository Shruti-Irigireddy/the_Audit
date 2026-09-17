class UserEntity {
  final String id;
  final String name;
  final String role;
  final bool defaultPic;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.role,
    required this.defaultPic,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });
}
