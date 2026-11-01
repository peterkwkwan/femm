import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/lab_upload_screen.dart';
import 'services/auth_service.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5D50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'femm',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hong Kong menopause care-navigation prototype',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'English UI only · not a diagnosis',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (usingPlaceholders) ...[
                const SizedBox(height: 16),
                Text(
                  'Supabase placeholders active — set SUPABASE_URL, '
                  'SUPABASE_ANON_KEY, and GOOGLE_SERVER_CLIENT_ID '
                  '(see root README).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
              const Spacer(),
              if (error != null) ...[
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: busy ? null : onGoogleSignIn,
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in with Google'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signed in',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('UID: ${user.id}'),
            if (user.email != null) Text('Email: ${user.email}'),
            if (displayName != null) Text('Name: $displayName'),
            const SizedBox(height: 16),
            Text(
              'Path A — upload a lab PDF, extract biomarkers, confirm rows. '
              'Not a diagnosis.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
