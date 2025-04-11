import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; // Add logger for debugging

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Logger _logger = Logger(); // Initialize logger

  /// Get the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Attempting email sign-in with: $email');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _logger.i('Sign-in successful, UID: ${credential.user?.uid}');
      await _updateUserLastLogin(credential.user?.uid);
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during sign-in: ${e.code} - ${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during sign-in: $e', error: e, stackTrace: stackTrace);
      throw Exception('An unexpected error occurred during sign-in: $e');
    }
  }

  /// Register with email and password
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _logger.i('Attempting registration with: $email');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        _logger.i('User created, UID: ${user.uid}');
        await user.updateDisplayName(name.trim());
        await _createUserDocument(
          uid: user.uid,
          email: email.trim(),
          name: name.trim(),
        );
      } else {
        _logger.w('No user returned after registration');
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during registration: ${e.code} - ${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during registration: $e', error: e, stackTrace: stackTrace);
      throw Exception('An unexpected error occurred during registration: $e');
    }
  }

  /// Sign in or register with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      _logger.i('Starting Google sign-in');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _logger.w('Google sign-in canceled by user');
        throw Exception('Google sign-in canceled by user');
      }

      _logger.i('Google user signed in: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        _logger.i('Google sign-in successful, UID: ${user.uid}');
        await _createUserDocument(
          uid: user.uid,
          email: user.email ?? googleUser.email,
          name: user.displayName ?? googleUser.displayName ?? 'User',
          photoUrl: user.photoURL ?? googleUser.photoUrl,
        );
      } else {
        _logger.w('No user returned after Google sign-in');
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during Google sign-in: ${e.code} - ${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during Google sign-in: $e', error: e, stackTrace: stackTrace);
      throw Exception('An unexpected error occurred during Google sign-in: $e');
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await _googleSignIn.signOut();
      await _auth.signOut();
      _logger.i('Sign-out successful');
    } catch (e) {
      _logger.e('Error signing out: $e');
      throw Exception('Error signing out: $e');
    }
  }

  /// Delete the current user's account
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      _logger.w('No user to delete');
      throw Exception('No user is currently signed in.');
    }

    try {
      _logger.i('Attempting to delete account for UID: ${user.uid}');
      if (user.providerData.any((info) => info.providerId == 'google.com')) {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google re-authentication canceled.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (password != null) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      } else {
        throw Exception('Password is required for email/password users.');
      }

      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      await _googleSignIn.signOut();
      _logger.i('Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during account deletion: ${e.code} - ${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.e('Error deleting account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email.trim());
      _logger.i('Password reset email sent');
    } on FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during password reset: ${e.code} - ${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logger.e('Error sending password reset email: $e');
      throw Exception('Failed to send password reset email: $e');
    }
  }

  /// Create or update user document in Firestore
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    try {
      _logger.i('Creating/updating user document for UID: $uid');
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'role': 'user',
        'isActive': true,
      }, SetOptions(merge: true));
      _logger.i('User document created/updated');
    } catch (e) {
      _logger.e('Failed to create/update user document: $e');
      throw Exception('Failed to create/update user document: $e');
    }
  }

  /// Update user's last login timestamp
  Future<void> _updateUserLastLogin(String? uid) async {
    if (uid == null) return;
    try {
      _logger.i('Updating last login for UID: $uid');
      await _firestore.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      _logger.i('Last login updated');
    } catch (e) {
      if (e.toString().contains('No document to update')) {
        _logger.w('No document to update for UID: $uid');
        return;
      }
      _logger.e('Failed to update last login: $e');
      throw Exception('Failed to update last login: $e');
    }
  }

  /// Map FirebaseAuthException to user-friendly messages
  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'invalid-email':
        return Exception('Invalid email format.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later.');
      case 'email-already-in-use':
        return Exception('This email is already registered.');
      case 'weak-password':
        return Exception('Password is too weak. Use at least 6 characters.');
      case 'requires-recent-login':
        return Exception('Please sign in again to verify your identity.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      default:
        return Exception(e.message ?? 'Authentication error');
    }
  }
}