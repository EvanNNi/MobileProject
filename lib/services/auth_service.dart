import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_repository.dart';

class AuthActionException implements Exception {
  const AuthActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize();
    _googleInitialized = true;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await UserRepository.instance.ensureUserDocument(credential.user);
    return credential;
  }

  Future<UserCredential> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
    await UserRepository.instance.ensureUserDocument(
      credential.user,
      displayName: name,
    );
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    await initializeGoogleSignIn();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthActionException('当前平台暂不支持 Google 弹窗登录。');
    }

    final account = await _googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthActionException('Google 没有返回可用的登录凭证。');
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _auth.signInWithCredential(credential);
    await UserRepository.instance.ensureUserDocument(userCredential.user);
    return userCredential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendPhoneCode({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: normalizePhoneNumber(phoneNumber),
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    final userCredential = await _auth.signInWithCredential(credential);
    await UserRepository.instance.ensureUserDocument(userCredential.user);
    return userCredential;
  }

  Future<UserCredential> signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    final userCredential = await _auth.signInWithCredential(credential);
    await UserRepository.instance.ensureUserDocument(userCredential.user);
    return userCredential;
  }

  Future<void> updateDisplayName(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final user = _auth.currentUser;
    await user?.updateDisplayName(trimmedName);
    if (user != null) {
      await UserRepository.instance.updateProfile(
        uid: user.uid,
        displayName: trimmedName,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google may not be configured yet; Firebase sign-out should still run.
    }
    await _auth.signOut();
  }

  static String normalizePhoneNumber(String rawPhone) {
    final compact = rawPhone.replaceAll(RegExp(r'[\s()-]'), '');
    if (compact.startsWith('+')) {
      return compact;
    }
    if (compact.startsWith('00')) {
      return '+${compact.substring(2)}';
    }
    if (RegExp(r'^1[3-9]\d{9}$').hasMatch(compact)) {
      return '+86$compact';
    }
    if (RegExp(r'^07\d{9}$').hasMatch(compact)) {
      return '+44${compact.substring(1)}';
    }

    throw const AuthActionException('请输入带国家区号的手机号，例如 +86 或 +44 开头。');
  }
}

String authErrorMessage(Object error) {
  if (error is AuthActionException) {
    return error.message;
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => '邮箱格式不正确。',
      'user-disabled' => '该账号已被禁用。',
      'user-not-found' => '没有找到这个账号，请先注册。',
      'wrong-password' => '密码不正确，请重新输入。',
      'invalid-credential' => '登录凭证无效，请检查账号和密码。',
      'email-already-in-use' => '这个邮箱已经注册过，可以直接登录。',
      'weak-password' => '密码强度太弱，建议至少 6 位。',
      'operation-not-allowed' => '这个登录方式暂时不可用，请换一种方式登录。',
      'network-request-failed' => '网络连接失败，请稍后重试。',
      'too-many-requests' => '请求太频繁，请稍后再试。',
      'invalid-phone-number' => '手机号格式不正确，请带上国家区号。',
      'invalid-verification-code' => '验证码不正确或已过期。',
      'missing-verification-code' => '请输入短信验证码。',
      'quota-exceeded' => '短信发送额度已用完，请稍后再试。',
      'app-not-authorized' => '当前 App 暂时无法使用这个登录方式。',
      _ => error.message ?? '认证失败，请稍后再试。',
    };
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => '你已取消 Google 登录。',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google 登录暂时不可用，请稍后再试。',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google 登录暂时不可用，请稍后再试。',
      GoogleSignInExceptionCode.uiUnavailable => '当前环境无法打开 Google 登录界面。',
      _ => error.description ?? 'Google 登录失败，请稍后再试。',
    };
  }
  if (error is PlatformException) {
    final rawMessage = [
      error.code,
      if (error.message != null) error.message,
      if (error.details != null) error.details.toString(),
    ].join(' ');
    if (rawMessage.contains('No active configuration') ||
        rawMessage.contains('GIDClientID')) {
      return 'Google 登录暂时不可用，请稍后再试。';
    }
    if (rawMessage.contains('missing support for the following URL schemes') ||
        rawMessage.contains('URL schemes')) {
      return 'Google 登录暂时不可用，请稍后再试。';
    }
    if (rawMessage.contains('network')) {
      return 'Google 登录网络请求失败，请检查网络后重试。';
    }
    return error.message ?? 'Google 登录暂时不可用，请稍后再试。';
  }
  return '操作失败，请稍后再试。';
}
