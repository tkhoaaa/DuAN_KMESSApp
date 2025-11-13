import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class AuthRepository {
  Stream<User?> authState();
  User? currentUser();

  Future<void> signOut();
  Future<void> signInAnonymously();
  Future<void> signInWithEmail(String email, String password);
  Future<void> registerWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendEmailVerification();
  Future<void> reloadCurrentUser();
  Future<void> signInWithCredential(AuthCredential credential);

  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onCompleted,
    required void Function(String verificationId) onTimeout,
  });

  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  });
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _google = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  @override
  Stream<User?> authState() => _auth.authStateChanges();

  @override
  User? currentUser() => _auth.currentUser;

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> signInAnonymously() => _auth.signInAnonymously();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> registerWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signInWithGoogle() async {
    final user = await _google.signIn();
    if (user == null) return;
    final auth = await user.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
    }
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) =>
      _auth.signInWithCredential(credential);

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onError,
    required void Function(PhoneAuthCredential credential) onCompleted,
    required void Function(String verificationId) onTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onCompleted,
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (verificationId) => onTimeout(verificationId),
    );
  }

  @override
  Future<void> confirmSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }
}

// Simple global instance for now (can be replaced later by DI)
final AuthRepository authRepository = FirebaseAuthRepository();

