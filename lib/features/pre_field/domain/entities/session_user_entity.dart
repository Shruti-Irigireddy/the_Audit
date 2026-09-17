import 'package:the_audit/features/auth/domain/entities/user_entity.dart';

class SessionUserEntity {
  final String id;
  final String sessionId;
  final String userId;
  final String role;
  final DateTime createdAt;

  const SessionUserEntity({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });
}

class SessionUserWithUserEntity {
  final SessionUserEntity sessionUser;
  final UserEntity user;

  const SessionUserWithUserEntity({
    required this.sessionUser,
    required this.user,
  });
}
