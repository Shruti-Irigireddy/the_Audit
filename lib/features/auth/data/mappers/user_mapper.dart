import 'package:the_audit/core/database/app_database.dart';
import 'package:the_audit/features/auth/domain/entities/user_entity.dart';

extension UserDbMapper on User {
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      role: role,
      defaultPic: defaultPic,
      email: email,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
