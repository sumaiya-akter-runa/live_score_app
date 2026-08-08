import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around [FirebaseAuth] so the UI layer never touches the SDK
/// directly. Keeps the rest of the app testable and makes it easy to swap in
/// another backend later.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Emits the current user (or `null` when signed out) whenever the auth
  /// state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in user, or `null` if no one is signed in.
  User? get currentUser => _auth.currentUser;

  /// Create a new account with [email] / [password] and return the user.
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with an existing [email] / [password] pair.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign the current user out.
  Future<void> signOut() => _auth.signOut();

  /// Translate raw Firebase exceptions into short, user-friendly strings.
  /// Falls back to a generic message for anything we don't recognize.
  static String humanize(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a moment.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
