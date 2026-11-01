import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'models/path_a_session.dart';
import 'screens/lab_upload_screen.dart';
import 'screens/match_gate_screen.dart';
import 'screens/spend_screen.dart';
import 'screens/survey_screen.dart';
import 'services/auth_service.dart';
import 'services/intake_service.dart';

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

class SignedInShell extends StatefulWidget {
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
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell> {
  final IntakeService _intake = IntakeService();
  PathASession? _session;
  bool _loadingSession = true;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _loadingSession = true;
      _sessionError = null;
    });
    try {
      final session = await _intake.fetchLatestSession();
      if (!mounted) return;
      setState(() {
        _session = session;
        _loadingSession = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sessionError = e.toString();
        _loadingSession = false;
      });
    }
  }

  Future<void> _openPath(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _loadSession();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.user.userMetadata ?? const <String, dynamic>{};
    final displayName = (meta['full_name'] ?? meta['name'])?.toString();
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('femm'),
        actions: [
          TextButton(
            onPressed: widget.busy ? null : widget.onSignOut,
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
            Text('UID: ${widget.user.id}'),
            if (widget.user.email != null) Text('Email: ${widget.user.email}'),
            if (displayName != null) Text('Name: $displayName'),
            const SizedBox(height: 16),
            Text(
              'Path A — labs → spend → survey → match. '
              'Care-navigation only — not a diagnosis.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await _openPath(const LabUploadScreen());
              },
              child: const Text('Upload lab PDF'),
            ),
            if (_loadingSession) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ] else if (session != null) ...[
              const SizedBox(height: 16),
              Text(
                'Continue Path A',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!session.hasSpend)
                OutlinedButton(
                  onPressed: () => _openPath(
                    SpendScreen(session: session, intakeService: _intake),
                  ),
                  child: const Text('Spend categories'),
                )
              else if (!session.hasSurvey)
                OutlinedButton(
                  onPressed: () => _openPath(
                    SurveyScreen(session: session, intakeService: _intake),
                  ),
                  child: const Text('Complete survey'),
                )
              else
                OutlinedButton(
                  onPressed: () => _openPath(
                    MatchGateScreen(session: session, intakeService: _intake),
                  ),
                  child: const Text('Open match gate'),
                ),
              const SizedBox(height: 8),
              Text(
                session.readyForMatch
                    ? 'Spend + survey done — open match for clinical hold + upsell.'
                    : 'Match stays locked until spend and survey are saved.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_sessionError != null) ...[
              const SizedBox(height: 12),
              Text(
                _sessionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (widget.error != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
