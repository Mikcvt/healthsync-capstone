import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Fetch UserModel from Firestore for given UID
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Stream UserModel in real-time
  Stream<UserModel?> streamUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Register with email, password, role & profile details
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('User creation failed: No user returned');
      }

      // Self-registration only ever produces a caregiver.
      //
      // Managed patients never reach this method — their account is created by
      // the Worker on the caregiver's behalf, and they sign in with a custom
      // token minted from an OTP. So a non-caregiver role arriving here is a
      // routing mistake, and it is rejected rather than defaulted: silently
      // creating a caregiver would grant permissions nobody asked for. The Auth
      // account already exists by this point, so it is rolled back first to
      // leave the email address usable.
      final normalizedRole = role.toLowerCase().trim();
      if (normalizedRole != 'caregiver') {
        await _rollbackRegistration(user);
        throw Exception(
          'Only caregiver accounts can be created here. If someone set '
          'HealthSync up for you, use the code they sent you instead.',
        );
      }
      const accountType = AccountType.caregiver;

      final userModel = UserModel(
        uid: user.uid,
        role: normalizedRole,
        accountType: accountType,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        canEditMedications: true,
        createdAt: DateTime.now(),
        isActive: true,
      );

      // The profile is written FIRST, before anything that can fail.
      //
      // An Auth account with no users/{uid} document is unrecoverable from the
      // app: registering again gives "email already in use" and signing in
      // gives "profile could not be loaded", so the person is locked out of
      // that address permanently. Anything non-essential — display name, the
      // verification email — happens after, and cannot abort registration.
      try {
        // merge: true because NotificationService may already have written an
        // fcm_token to this document from the auth-state listener. A plain set
        // would silently wipe it.
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap(), SetOptions(merge: true));

        // Only a caregiver_profile is written here. The patient_profile branch
        // that used to sit alongside it served self-managing accounts; a managed
        // patient's profile is created by the Worker when a caregiver adds them.
        await _firestore.collection('caregiver_profile').doc(user.uid).set({
          'profile_id': user.uid,
          'user_ref': user.uid,
          'alert_pref_missed': true,
          'alert_pref_low_stock': true,
          'alert_pref_daily': true,
          'created_at': Timestamp.now(),
        }, SetOptions(merge: true));
      } catch (e) {
        await _rollbackRegistration(user);
        throw Exception(
          'Could not finish creating your account. Please check your '
          'connection and try again.',
        );
      }

      // Best-effort extras. A failure here leaves a usable account, so it must
      // not propagate — the user can resend verification from the next screen.
      try {
        await user.updateDisplayName('$firstName $lastName'.trim());
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Post-registration step failed (non-fatal): $e');
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  /// Undoes a half-finished registration so the email address stays usable.
  ///
  /// Without this, a dropped connection partway through costs the person that
  /// address forever: registering again gives "email already in use" and
  /// signing in gives "profile could not be loaded".
  ///
  /// The Firestore documents must go too. NotificationService writes an
  /// fcm_token to users/{uid} as soon as the auth state changes, which happens
  /// before registration finishes, so deleting only the Auth account would
  /// leave that document orphaned with no owner.
  Future<void> _rollbackRegistration(User user) async {
    for (final ref in [
      _firestore.collection('users').doc(user.uid),
      _firestore.collection('patient_profile').doc(user.uid),
      _firestore.collection('caregiver_profile').doc(user.uid),
    ]) {
      try {
        await ref.delete();
      } catch (_) {
        // Best effort — the caller's thrown error is the useful signal.
      }
    }
    try {
      await user.delete();
    } catch (_) {
      // Deletion can itself fail offline; the caller's error is still more
      // useful than this one.
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        return await getUserProfile(user.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Send password reset email
  /// Signs in with a custom token minted by the Worker after a valid OTP.
  ///
  /// This is how managed patients authenticate: no email, no password, no
  /// sign-up. Firebase treats the resulting session like any other.
  Future<UserCredential> signInWithCustomToken(String token) async {
    try {
      return await _auth.signInWithCustomToken(token);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('You must be signed in to verify your email.');
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw Exception('You must be signed in to edit your profile.');
    final updatedName = '$firstName $lastName'.trim();
    await firebaseUser.updateDisplayName(updatedName);
    final current = await getUserProfile(firebaseUser.uid);
    if (current == null) throw Exception('Your profile could not be loaded.');
    final updated = current.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: phone.trim(),
    );
    await _firestore.collection('users').doc(firebaseUser.uid).set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    final email = firebaseUser?.email;
    if (firebaseUser == null || email == null) throw Exception('You must be signed in to change your password.');
    final credential = EmailAuthProvider.credential(email: email, password: currentPassword);
    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }

  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).update({'is_active': false});
    await user.delete();
  }

  Future<bool> reloadAndCheckEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Convert Firebase Auth error codes into clean, user-friendly messages
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
