import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign-in error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Sign-in unexpected error: $e');
      }
      rethrow;
    }
  }

  // Create user with email and password
  Future<UserCredential?> createUserWithEmailPassword(
      String email, String password, String displayName) async {
    try {
      final UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name
      if (result.user != null) {
        await result.user!.updateDisplayName(displayName);
      }

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign-up error: ${e.code} - ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Sign-up unexpected error: $e');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Check if user is email verified
  bool get isEmailVerified =>
      _auth.currentUser?.emailVerified ?? false;

  // Send email verification
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Reload user (to get fresh data)
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}