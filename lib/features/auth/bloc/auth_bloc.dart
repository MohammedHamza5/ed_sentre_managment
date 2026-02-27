/// Authentication BLoC
/// إدارة حالة المصادقة
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/auth_service.dart';
import '../../../core/supabase/supabase_client.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// التحقق من حالة المصادقة الحالية
class AuthCheckRequested extends AuthEvent {}

/// تسجيل الدخول
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// تسجيل الخروج
class AuthLogoutRequested extends AuthEvent {}

/// إعادة تعيين كلمة المرور
class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

/// تسجيل حساب جديد
class AuthSignupRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String phone;

  const AuthSignupRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
  });

  @override
  List<Object?> get props => [name, email, password, phone];
}

/// تم اكتشاف نشاط للمستخدم (لإعادة تعيين مؤقت الجلسة)
class AuthInteractionDetected extends AuthEvent {}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final Map<String, dynamic>? userData;
  final String? errorMessage;
  final String? successMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.userData,
    this.errorMessage,
    this.successMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Map<String, dynamic>? userData,
    String? errorMessage,
    String? successMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      userData: userData ?? this.userData,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    user,
    userData,
    errorMessage,
    successMessage,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  Timer? _sessionTimer;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  AuthBloc() : super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthSignupRequested>(_onSignupRequested);
    on<AuthInteractionDetected>(_onInteractionDetected);

    // الاستماع لتغييرات المصادقة
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    SupabaseClientManager.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        add(AuthCheckRequested());
      } else if (event == AuthChangeEvent.signedOut) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      }
    });
  }

  /// التحقق من حالة المصادقة الحالية
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final user = SupabaseClientManager.currentUser;

      if (user != null) {
        final userData = await AuthService.getCurrentUserData();

        // Update RoleProvider with user data
        // Note: This requires context, so we'll handle it in the UI layer

        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            userData: userData,
            errorMessage: null,
          ),
        );
        _startSessionTimer(); // Start timer on check success
      } else {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'فشل التحقق من حالة المصادقة',
        ),
      );
    }
  }

  /// تسجيل الدخول
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await AuthService.signInWithEmail(
      email: event.email,
      password: event.password,
    );

    if (result.success) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          userData: result.userData,
          errorMessage: null,
          successMessage: 'تم تسجيل الدخول بنجاح',
        ),
      );
      _startSessionTimer(); // Start timer on login success
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.errorMessage,
        ),
      );
    }
  }

  /// تسجيل الخروج
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    await AuthService.signOut();
    _cancelSessionTimer(); // Cancel timer on logout

    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// إعادة تعيين كلمة المرور
  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await AuthService.resetPassword(event.email);

    if (result.success) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          successMessage:
              'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني',
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.errorMessage,
        ),
      );
    }
  }

  /// تسجيل حساب جديد
  Future<void> _onSignupRequested(
    AuthSignupRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await AuthService.signUp(
      email: event.email,
      password: event.password,
      fullName: event.name,
      phone: event.phone,
    );

    if (result.success) {
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          userData: result.userData,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.errorMessage,
        ),
      );
    }
  }

  void _onInteractionDetected(
    AuthInteractionDetected event,
    Emitter<AuthState> emit,
  ) {
    if (state.status == AuthStatus.authenticated) {
      _startSessionTimer(); // Reset timer
    }
  }

  void _startSessionTimer() {
    _cancelSessionTimer();
    _sessionTimer = Timer(_sessionTimeout, () {
      add(AuthLogoutRequested());
      // Optionally notify user via a specialized event or state
    });
  }

  void _cancelSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  @override
  Future<void> close() {
    _cancelSessionTimer();
    return super.close();
  }
}


