import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

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

      // Update Firebase Auth display name
      await user.updateDisplayName('$firstName $lastName'.trim());

      final userModel = UserModel(
        uid: user.uid,
        role: role.toLowerCase().trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Save to Firestore `users` collection
      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      // If patient, initialize empty patient_profile
      if (userModel.isPatient) {
        await _firestore.collection('patient_profile').doc(user.uid).set({
          'profile_id': user.uid,
          'user_ref': user.uid,
          'medical_conditions': <String>[],
          'allergies': <String>[],
          'emergency_contact': '',
          'emergency_phone': '',
          'caregiver_ref': null,
          'created_at': Timestamp.now(),
        }, SetOptions(merge: true));
      } else if (userModel.isCaregiver) {
        // If caregiver, initialize caregiver_profile
        await _firestore.collection('caregiver_profile').doc(user.uid).set({
          'profile_id': user.uid,
          'user_ref': user.uid,
          'alert_pref_missed': true,
          'alert_pref_vitals': true,
          'alert_pref_daily': true,
          'created_at': Timestamp.now(),
        }, SetOptions(merge: true));
      }

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
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
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
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
