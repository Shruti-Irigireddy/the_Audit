import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

import 'package:the_audit/features/auth/data/current_user_repository.dart';

/// A business rule the user broke ("No-Go requires a reason."). Its
/// [message] is written for the user and shown as is.
class AppFailure implements Exception {
  final String message;

  const AppFailure(this.message);

  @override
  String toString() => message;
}

/// The message to show the user for [error]. The full error still goes to
/// the logs; this never shows raw exception text.
String friendlyError(Object error) {
  if (error is AppFailure) return error.message;
  if (error is NotSignedInException) return error.toString();

  final text = error.toString();
  // Database refusals (foreign key, unique, not null, check). Drift may wrap
  // the SqliteException when the database runs in a background isolate.
  if (text.contains('SqliteException')) {
    return text.contains('constraint failed')
        ? "This couldn't be saved because related data is missing or "
              'already exists.'
        : 'Something went wrong. Please try again.';
  }
  if (error is TimeoutException ||
      error is SocketException ||
      (error is FirebaseException &&
          const {
            'unavailable',
            'deadline-exceeded',
            'network-request-failed',
          }.contains(error.code))) {
    return 'No connection — showing saved data.';
  }
  // A plain Exception('...') still carries a message meant for the user;
  // drop Dart's "Exception: " prefix.
  if (error is Exception && text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return 'Something went wrong. Please try again.';
}
