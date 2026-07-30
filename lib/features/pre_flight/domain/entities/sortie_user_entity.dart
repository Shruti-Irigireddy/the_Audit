import 'package:the_audit/features/auth/domain/entities/user_entity.dart';

class SortieUserEntity {
  final String id;
  final String flightId;
  final String userId;
  final String role;
  final DateTime createdAt;

  const SortieUserEntity ({
    required this.id,
    required this.flightId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });
}

class SortieUserWithUserEntity {
  final SortieUserEntity sortieUser;
  final UserEntity user;

  const SortieUserWithUserEntity ({
    required this.sortieUser,
    required this.user,
  });
}