import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  UserModel? _currentUserModel;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _userProfileSubscription;

  AuthProvider() {
    _initAuthListener();
  }

  UserModel? get currentUserModel => _currentUserModel;
  bool get isAuthenticated => _authService.currentUser != null && _currentUserModel != null;
  bool get isPatient => _currentUserModel?.isPatient ?? true;
  bool get isCaregiver => _currentUserModel?.isCaregiver ?? false;
  bool get isSolo => _currentUserModel?.isSolo ?? false;
  bool get isManaged => _currentUserModel?.isManaged ?? false;

  /// Whether this user may author medications. Screens gate edit controls on
  /// this, never on [isPatient] — a solo user is a patient who may edit.
  bool get canEditMedications =>
      _currentUserModel?.canEditMedications ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUid => _authService.currentUser?.uid;
  bool get isEmailVerified => _authService.isEmailVerified;

  void _initAuthListener() {
    _authSubscription = _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _listenToUserProfile(user.uid);
      } else {
        _userProfileSubscription?.cancel();
        _currentUserModel = null;
        notifyListeners();
      }
    });
  }

  void _listenToUserProfile(String uid) {
    _userProfileSubscription?.cancel();
    NotificationService().saveTokenToUser(uid);
    _userProfileSubscription = _authService.streamUserProfile(uid).listen((profile) {
      _currentUserModel = profile;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sign In
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (user == null) {
        throw Exception('Your account profile could not be loaded. Please contact support.');
      }
      _currentUserModel = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Signs a managed patient in with the code their caregiver gave them.
  ///
  /// The Worker validates the code and returns a Firebase custom token; from
  /// there it is an ordinary Firebase session. The patient never has a password
  /// and never sees a sign-up form.
  ///
  /// Returns the redemption on success, or null — with [errorMessage] set and
  /// [lastOtpErrorCode] carrying the machine-readable reason — on failure.
  Future<OtpRedemption?> signInWithOtp(String code) async {
    _setLoading(true);
    _errorMessage = null;
    _lastOtpErrorCode = null;
    try {
      final redemption = await _apiService.redeemOtp(code);
      if (redemption.token.isEmpty) {
        throw Exception('That code could not be used. Please ask for a new one.');
      }

      await _authService.signInWithCustomToken(redemption.token);

      // The auth listener picks up the profile stream, but the success screen
      // needs the model immediately rather than a frame later.
      _currentUserModel = await _authService.getUserProfile(redemption.uid);

      _setLoading(false);
      return redemption;
    } on ApiException catch (e) {
      _lastOtpErrorCode = e.code;
      _errorMessage = e.message;
      _setLoading(false);
      return null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return null;
    }
  }

  String? _lastOtpErrorCode;

  /// Machine-readable reason the last OTP attempt failed: `invalid_code`,
  /// `code_used`, `code_expired` or `rate_limited`.
  String? get lastOtpErrorCode => _lastOtpErrorCode;

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String role,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        role: role,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      _currentUserModel = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Password Reset
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Email verification
  Future<bool> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Reload profile
  Future<void> reloadUserProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _currentUserModel = await _authService.getUserProfile(uid);
      notifyListeners();
    }
  }

  Future<bool> reloadAndCheckEmailVerification() async {
    final verified = await _authService.reloadAndCheckEmailVerification();
    notifyListeners();
    return verified;
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUserModel = await _authService.updateCurrentUserProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _authService.deleteCurrentUser();
      _currentUserModel = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUserModel = null;
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userProfileSubscription?.cancel();
    super.dispose();
  }
}
