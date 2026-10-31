import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';

/// Pass `--dart-define=USE_FIREBASE_EMULATOR=true` to talk to local emulators.
const bool kUseFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kUseFirebaseEmulator) {
    // 10.0.2.2 is the Android emulator host loopback.
    const host = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

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
  late final AuthService _authService =
      widget.authService ?? AuthService();
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
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
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
          useEmulator: kUseFirebaseEmulator,
          onGoogleSignIn: () => _run(() async {
            await _authService.signInWithGoogle();
          }),
          onEmulatorSignIn: () => _run(() async {
            await _authService.signInAnonymouslyForEmulator();
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
    required this.useEmulator,
    required this.onGoogleSignIn,
    required this.onEmulatorSignIn,
  });

  final bool busy;
  final String? error;
  final bool useEmulator;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onEmulatorSignIn;

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
              if (useEmulator) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : onEmulatorSignIn,
                  child: const Text('Emulator anonymous sign-in'),
                ),
              ],
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
            Text('UID: ${user.uid}'),
            if (user.email != null) Text('Email: ${user.email}'),
            if (user.displayName != null) Text('Name: ${user.displayName}'),
            const SizedBox(height: 16),
            const Text(
              'Phase 0 shell — Path A flow lands in later phases.',
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
