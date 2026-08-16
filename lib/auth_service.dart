import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around [FirebaseAuth] so the UI layer never touches the SDK
/// directly. Keeps the rest of the app testable and makes it easy to swap in
/// another backend later.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Lazily constructed so unit tests / web can still instantiate the class
  /// even if the native plugin isn't available.
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get _google => _googleSignIn ??= GoogleSignIn();

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

  /// Start the Google Sign-In flow and exchange the resulting id-token with
  /// Firebase Auth. Returns `null` if the user dismisses the chooser.
  ///
  /// On web we have to pass the [FirebaseAuth] instance into the
  /// `signInSilently`/`signIn` calls; the [GoogleSignIn] plugin handles the
  /// SDK initialization automatically on Android/iOS.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    // Make sure any previously signed-in account from a prior session is
    // forgotten so the chooser shows every time.
    await _google.signOut();

    final GoogleSignInAccount? account = await _google.signIn();
    if (account == null) return null; // user cancelled

    final GoogleSignInAuthentication auth = await account.authentication;
    // On iOS we may get an `accessToken` but not an `idToken`. Only one is
    // needed for Firebase, so prefer idToken when available.
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign the current user out. Clears both Firebase Auth and the Google
  /// Sign-In session so a future "Continue with Google" shows the chooser.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _google.signOut();
      } catch (_) {
        // Best-effort: Google sign-out can fail if the user never used it.
      }
    }
    await _auth.signOut();
  }

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
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Translate a raw `GoogleSignIn` / `signInWithCredential` exception into
  /// something user-friendly. Recognizes the common failure codes so the UI
  /// can give an actionable message instead of a vague "failed".
  static String humanizeGoogle(Object error) {
    final msg = error.toString();

    // Cancellation from either the Google plugin or Firebase.
    if (msg.toLowerCase().contains('cancel')) {
      return 'Sign-in cancelled.';
    }
    if (msg.toLowerCase().contains('network')) {
      return 'Network error. Check your connection and try again.';
    }

    // google_sign_in throws PlatformException with error codes:
    //   10 = DEVELOPER_ERROR (bad SHA-1/SHA-256, missing google-services.json,
    //        or wrong package name in Firebase Console).
    //    4 = SIGN_IN_REQUIRED / SIGN_IN_CURRENTLY_IN_PROGRESS — usually retry.
    //    7 = NETWORK_ERROR.
    //    8 = INTERNAL_ERROR.
    //   16 = SIGN_IN_FAILED.
    //   12501 = user cancelled (mobile services).
    if (msg.contains('ApiException: 10') ||
        msg.contains('DeveloperError') ||
        msg.contains('DEVELOPER_ERROR')) {
      return 'Google sign-in is not configured for this app. '
          'Add the SHA-1 and SHA-256 fingerprints of your debug keystore '
          'in the Firebase Console (Project Settings → Android app).';
    }
    if (msg.contains('ApiException: 4') ||
        msg.contains('SIGN_IN_REQUIRED') ||
        msg.contains('SIGN_IN_CURRENTLY_IN_PROGRESS')) {
      return 'Another sign-in is already in progress. Please wait a moment and try again.';
    }
    if (msg.contains('ApiException: 7') || msg.contains('NETWORK_ERROR')) {
      return 'Network error. Check your connection and try again.';
    }
    if (msg.contains('ApiException: 8') || msg.contains('INTERNAL_ERROR')) {
      return 'Google sign-in hit an internal error. Please try again.';
    }
    if (msg.contains('ApiException: 16') || msg.contains('SIGN_IN_FAILED')) {
      return 'Google sign-in failed. Make sure Google Play Services is up to date.';
    }

    // Last-resort fallback that still surfaces the raw exception so the
    // developer can see what's actually happening while debugging.
    return 'Google sign-in failed: $msg';
  }
}
