import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Auth + Firestore `users/{uid}` upsert for the femm user client.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInit;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleInitialized() {
    // Optional: --dart-define=GOOGLE_SERVER_CLIENT_ID=<Web client ID>
    // so Android returns an ID token for Firebase Auth.
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    return _googleInit ??= _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
  }

  /// Signs in with Google, then writes / merges `users/{uid}`.
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final GoogleSignInAccount account = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await _upsertUserDoc(userCredential.user);
    return userCredential;
  }

  /// Emulator / local smoke path when Google OAuth client IDs are not wired.
  /// Still creates `users/{uid}` so Firestore wiring can be verified.
  Future<UserCredential> signInAnonymouslyForEmulator() async {
    final userCredential = await _auth.signInAnonymously();
    await _upsertUserDoc(userCredential.user);
    return userCredential;
  }

  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await Future.wait<void>([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> _upsertUserDoc(User? user) async {
    if (user == null) {
      return;
    }
    final ref = _firestore.collection('users').doc(user.uid);
    final existing = await ref.get();
    final data = <String, Object?>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'role': 'user',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await ref.set(data, SetOptions(merge: true));
  }
}
