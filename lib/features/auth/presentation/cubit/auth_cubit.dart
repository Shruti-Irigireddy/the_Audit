import 'package:bloc/bloc.dart';

import 'package:the_audit/core/errors/app_failure.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/features/auth/data/auth_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  static const _log = AppLogger('AuthCubit');

  final AuthStorage _authStorage;

  AuthCubit(this._authStorage) : super(AuthState.initial());

  Future<void> loadSession() async {
    _log.t('loadSession()');
    emit(
      state.copyWith(viewStatus: AuthViewStatus.loading, errorMessage: null),
    );

    try {
      final isLoggedIn = await _authStorage.isLoggedIn();
      final uid = await _authStorage.getUid();
      final email = await _authStorage.getEmail();
      _log.i(
        isLoggedIn
            ? 'session restored: ${AppLogger.mask(email)}'
            : 'no stored session',
      );

      emit(
        state.copyWith(
          viewStatus: isLoggedIn
              ? AuthViewStatus.authenticated
              : AuthViewStatus.unauthenticated,
          isLoggedIn: isLoggedIn,
          uid: uid,
          email: email,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('loadSession failed', error, stackTrace);
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  /// Signs the user in for this run. Only when [remember] is true is the
  /// session stored, so the next launch opens straight to home; otherwise any
  /// previously remembered session is cleared.
  Future<void> saveSession({
    required String uid,
    required String email,
    bool remember = false,
  }) async {
    _log.i('login: ${AppLogger.mask(email)} (remember: $remember)');
    emit(
      state.copyWith(viewStatus: AuthViewStatus.loading, errorMessage: null),
    );

    try {
      if (remember) {
        await _authStorage.saveSession(uid, email);
      } else {
        await _authStorage.clearSession();
      }
      _log.d('session saved');
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.authenticated,
          isLoggedIn: true,
          uid: uid,
          email: email,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('saveSession failed', error, stackTrace);
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }

  Future<void> clearSession() async {
    _log.i('logout: ${AppLogger.mask(state.email)}');
    emit(
      state.copyWith(viewStatus: AuthViewStatus.loading, errorMessage: null),
    );

    try {
      await _authStorage.clearSession();
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.unauthenticated,
          isLoggedIn: false,
          uid: null,
          email: null,
          errorMessage: null,
        ),
      );
    } catch (error, stackTrace) {
      _log.e('clearSession failed', error, stackTrace);
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: friendlyError(error),
        ),
      );
    }
  }
}
