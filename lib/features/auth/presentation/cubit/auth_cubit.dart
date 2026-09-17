import 'package:bloc/bloc.dart';

import 'package:the_audit/features/auth/data/auth_storage.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthStorage _authStorage;

  AuthCubit(this._authStorage) : super(AuthState.initial());

  Future<void> loadSession() async {
    emit(
      state.copyWith(viewStatus: AuthViewStatus.loading, errorMessage: null),
    );

    try {
      final isLoggedIn = await _authStorage.isLoggedIn();
      final uid = await _authStorage.getUid();
      final email = await _authStorage.getEmail();

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
    } catch (error) {
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> saveSession({required String uid, required String email}) async {
    emit(
      state.copyWith(viewStatus: AuthViewStatus.loading, errorMessage: null),
    );

    try {
      await _authStorage.saveSession(uid, email);
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.authenticated,
          isLoggedIn: true,
          uid: uid,
          email: email,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> clearSession() async {
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
    } catch (error) {
      emit(
        state.copyWith(
          viewStatus: AuthViewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
