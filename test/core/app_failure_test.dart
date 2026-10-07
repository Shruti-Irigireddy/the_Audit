import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/features/auth/data/current_user_repository.dart';

void main() {
  test('a broken rule shows its own message', () {
    expect(
      friendlyError(const AppFailure('No-Go requires a reason.')),
      'No-Go requires a reason.',
    );
  });

  test('a plain Exception loses the "Exception: " prefix', () {
    expect(
      friendlyError(Exception('Cannot start flight without GO decision.')),
      'Cannot start flight without GO decision.',
    );
  });

  test('database constraint errors are never shown raw', () {
    final message = friendlyError(
      Exception(
        'SqliteException(787): while executing, FOREIGN KEY constraint '
        'failed, constraint failed (code 787)',
      ),
    );
    expect(message, isNot(contains('Sqlite')));
    expect(message, contains("couldn't be saved"));
  });

  test('no connection and not signed in have their own messages', () {
    expect(
      friendlyError(TimeoutException('slow')),
      'No connection — showing saved data.',
    );
    expect(
      friendlyError(NotSignedInException()),
      'Sign in again to save changes.',
    );
  });

  test('anything else gets a generic message', () {
    expect(
      friendlyError(StateError('Bad state: no element')),
      'Something went wrong. Please try again.',
    );
  });
}
