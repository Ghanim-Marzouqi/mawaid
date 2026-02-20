import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';
import '../utils/push_token.dart';

class AuthState {
  final Session? session;
  final Profile? profile;
  final bool isLoading;

  const AuthState({this.session, this.profile, this.isLoading = true});

  AuthState copyWith({
    Session? session,
    Profile? profile,
    bool? isLoading,
    bool clearSession = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  bool _signingOut = false;
  StreamSubscription? _authSub;

  @override
  AuthState build() => const AuthState();

  Future<void> initialize() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      state = state.copyWith(session: session);
      await fetchProfile();
      registerPushToken(); // fire-and-forget
    }
    state = state.copyWith(isLoading: false);

    _authSub?.cancel();
    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      if (!ref.mounted || _signingOut) return;
      if (data.session == null) {
        state = const AuthState(isLoading: false);
      } else {
        state = state.copyWith(session: data.session);
        await fetchProfile();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _signingOut = false;
    state = state.copyWith(session: response.session);
    await fetchProfile();
    registerPushToken(); // fire-and-forget
  }

  /// Call supabase.auth.signOut() and clear local state.
  /// Returns after both are done. The caller is responsible for navigation.
  Future<void> signOut() async {
    _signingOut = true;
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    state = const AuthState(isLoading: false);
    _signingOut = false;
  }

  Future<void> fetchProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    if (!ref.mounted) return;
    state = state.copyWith(profile: Profile.fromJson(data));
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
