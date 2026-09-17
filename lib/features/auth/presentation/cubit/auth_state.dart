enum AuthViewStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  failure,
}

class AuthState {
  static const Object _unset = Object();

  final AuthViewStatus viewStatus;
  final bool isLoggedIn;
  final String? uid;
  final String? email;
  final String? errorMessage;

  const AuthState({
    required this.viewStatus,
    required this.isLoggedIn,
    required this.uid,
    required this.email,
    required this.errorMessage,
  });

  factory AuthState.initial() {
    return const AuthState(
      viewStatus: AuthViewStatus.initial,
      isLoggedIn: false,
      uid: null,
      email: null,
      errorMessage: null,
    );
  }

  AuthState copyWith({
    AuthViewStatus? viewStatus,
    bool? isLoggedIn,
    Object? uid = _unset,
    Object? email = _unset,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      viewStatus: viewStatus ?? this.viewStatus,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      uid: identical(uid, _unset) ? this.uid : uid as String?,
      email: identical(email, _unset) ? this.email : email as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  bool get isLoading => viewStatus == AuthViewStatus.loading;

  bool get isAuthenticated => viewStatus == AuthViewStatus.authenticated;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}
