import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService(this._firebaseAuth);

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;
  bool get isAnonymous => _firebaseAuth.currentUser?.isAnonymous ?? true;

  // ──────────────────────────────────────────────────────────────
  // Call once at app startup (e.g. in main.dart after Firebase.initializeApp)
  // This sets up Google Sign-In and triggers lightweight (silent) auth.
  // ──────────────────────────────────────────────────────────────
  static Future<void> initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize();
      // Note: We intentionally do NOT call attemptLightweightAuthentication()
      // here because the app uses anonymous-first auth. Google sign-in is
      // triggered only when the user explicitly taps the button.
    } catch (e) {
      debugPrint('GoogleSignIn.initialize error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Anonymous Sign-In (silent, on app launch)
  // ──────────────────────────────────────────────────────────────
  Future<UserCredential> signInAnonymously() async {
    return await _firebaseAuth.signInAnonymously();
  }

  // ──────────────────────────────────────────────────────────────
  // Google Sign-In — native Credential Manager (Android) / GIDSignIn (iOS)
  // Uses google_sign_in v7 authenticate() which shows the native account
  // picker bottomsheet WITHOUT opening a browser.
  // ──────────────────────────────────────────────────────────────
  Future<UserCredential> signInWithGoogle() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      // Web fallback
      return await _firebaseAuth.signInWithProvider(GoogleAuthProvider());
    }

    // authenticate() opens the native Credential Manager / GIDSignIn popup
    // and emits the result on authenticationEvents stream.
    // We capture it by listening before calling authenticate().
    final completer = Completer<GoogleSignInAccount>();
    late StreamSubscription sub;
    sub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          completer.complete(event.user);
          sub.cancel();
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          completer.completeError(Exception('Google Sign-In cancelled.'));
          sub.cancel();
        }
      },
      onError: (e) {
        completer.completeError(e);
        sub.cancel();
      },
    );

    try {
      await GoogleSignIn.instance.authenticate();
    } catch (e) {
      sub.cancel();
      rethrow;
    }

    final account = await completer.future;
    // v7: authentication is a sync getter — only carries idToken
    final auth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      // accessToken is via a separate authorization flow in v7;
      // idToken alone is sufficient for Firebase authentication.
    );

    return await _linkOrSignIn(credential);
  }

  // ──────────────────────────────────────────────────────────────
  // Email Sign-In with Account Linking
  // ──────────────────────────────────────────────────────────────
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return await _linkOrSignIn(credential);
  }

  // ──────────────────────────────────────────────────────────────
  // Email Registration with Account Linking
  // ──────────────────────────────────────────────────────────────
  Future<UserCredential> registerWithEmail(String email, String password) async {
    final user = _firebaseAuth.currentUser;

    if (user != null && user.isAnonymous) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      try {
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
          debugPrint('Account linking: existing account found, signing in instead.');
          return await _firebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        rethrow;
      }
    }

    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Private: Link credential to anonymous account or sign in directly
  // ──────────────────────────────────────────────────────────────
  Future<UserCredential> _linkOrSignIn(AuthCredential credential) async {
    final user = _firebaseAuth.currentUser;

    if (user != null && user.isAnonymous) {
      try {
        return await user.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          debugPrint('Account linking: credential in use, signing in instead.');
          return await _firebaseAuth.signInWithCredential(credential);
        }
        rethrow;
      }
    }

    return await _firebaseAuth.signInWithCredential(credential);
  }

  // ──────────────────────────────────────────────────────────────
  // Sign Out
  // ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
    await _firebaseAuth.signOut();
  }

  // ──────────────────────────────────────────────────────────────
  // Delete Account
  // ──────────────────────────────────────────────────────────────
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      debugPrint('[AuthService] No user to delete.');
      return;
    }

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    try {
      debugPrint('[AuthService] Cleaning up Firestore data for UID: $uid');
      // 1. Cleanup user data (Settings first)
      await db.collection('users').doc(uid).collection('settings').doc('app').delete();
      await db.collection('users').doc(uid).delete();
      debugPrint('[AuthService] Firestore cleanup successful.');

      // 2. Delete user
      debugPrint('[AuthService] Deleting user from Firebase Auth...');
      await user.delete();
      debugPrint('[AuthService] Firebase Auth deletion successful.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException during deletion: ${e.code} - ${e.message}');
      if (e.code == 'requires-recent-login') {
        throw Exception('re-auth-required');
      }
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during deletion: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Re-authentication helper (for account deletion)
  // ──────────────────────────────────────────────────────────────
  Future<void> reauthenticateWithGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    debugPrint('[AuthService] Starting re-authentication flow with Google...');
    final completer = Completer<GoogleSignInAccount>();
    late StreamSubscription sub;
    sub = GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        debugPrint('[AuthService] Google Sign-In event captured.');
        completer.complete(event.user);
        sub.cancel();
      }
    });

    try {
      await GoogleSignIn.instance.authenticate();
      final account = await completer.future;
      debugPrint('[AuthService] Google account retrieved for re-auth.');
      final auth = account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
      
      debugPrint('[AuthService] Re-authenticating user with new credential...');
      await user.reauthenticateWithCredential(credential);
      debugPrint('[AuthService] Re-authentication successful.');
    } catch (e) {
      debugPrint('[AuthService] Re-authentication failed: $e');
      sub.cancel();
      rethrow;
    }
  }
}

