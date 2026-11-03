import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/signed_in_home.dart';
import 'services/auth_service.dart';
import 'theme/petal_soft.dart';
import 'widgets/dawn_mist_welcome.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const FemmApp());
}

class FemmApp extends StatelessWidget {
  const FemmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'femm',
      debugShowCheckedModeBanner: false,
      theme: PetalSoft.theme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService = widget.authService ?? AuthService();
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      setState(() {
        _error = switch (error) {
          AuthException(:final message) => message,
          StateError(:final message) => message,
          _ => error.toString(),
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? _authService.currentSession;
        final user = session?.user ?? _authService.currentUser;
        if (user != null) {
          return SignedInShell(
            user: user,
            busy: _busy,
            error: _error,
            onSignOut: () => _run(_authService.signOut),
          );
        }
        return SignInShell(
          busy: _busy,
          error: _error,
          usingPlaceholders: !SupabaseConfig.hasRealProject,
          onGoogleSignIn: () => _run(() async {
            await _authService.signInWithGoogle();
          }),
        );
      },
    );
  }
}

class SignInShell extends StatelessWidget {
  const SignInShell({
    super.key,
    required this.busy,
    required this.error,
    required this.usingPlaceholders,
    required this.onGoogleSignIn,
  });

  final bool busy;
  final String? error;
  final bool usingPlaceholders;
  final VoidCallback onGoogleSignIn;

  @override
  Widget build(BuildContext context) {
    return DawnMistWelcome(
      busy: busy,
      error: error,
      usingPlaceholders: usingPlaceholders,
      onGoogleSignIn: onGoogleSignIn,
    );
  }
}

class SignedInShell extends StatelessWidget {
  const SignedInShell({
    super.key,
    required this.user,
    required this.busy,
    required this.error,
    required this.onSignOut,
  });

  final User user;
  final bool busy;
  final String? error;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SignedInHome(
      user: user,
      busy: busy,
      error: error,
      onSignOut: onSignOut,
    );
  }
}
