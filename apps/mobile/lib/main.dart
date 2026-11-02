import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'constants/disclaimers.dart';
import 'screens/lab_upload_screen.dart';
import 'services/auth_service.dart';
import 'theme/petal_soft.dart';
import 'widgets/deep_accent_dusk_welcome.dart';

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
        _error = error.toString();
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
    return DeepAccentDuskWelcome(
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
    final theme = Theme.of(context);
    final meta = user.userMetadata ?? const <String, dynamic>{};
    final displayName = (meta['full_name'] ?? meta['name'])?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('femm'),
        actions: [
          TextButton(
            onPressed: busy ? null : onSignOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Signed in',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (displayName != null)
              Text(
                displayName,
                style: theme.textTheme.titleMedium,
              ),
            if (user.email != null)
              Text(
                user.email!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: PetalSoft.muted,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Path A — labs → routine → symptoms → match. '
              '${FemmDisclaimers.oneLiner}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: PetalSoft.muted,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LabUploadScreen(),
                  ),
                );
              },
              child: const Text('Upload lab PDF'),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
