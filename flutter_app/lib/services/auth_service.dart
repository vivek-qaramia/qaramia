import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String displayName,
    String? ageRange,
    String? country,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = AppUser(
      uid: credential.user!.uid,
      username: username,
      displayName: displayName,
      createdAt: DateTime.now(),
      ageRange: ageRange,
      country: country,
    );
    await _db.collection('users').doc(user.uid).set(user.toJson());
    return user;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    final uid = result.user!.uid;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) {
      final username = googleUser.email.split('@').first;
      final user = AppUser(
        uid: uid,
        username: username,
        displayName: googleUser.displayName ?? username,
        avatarUrl: googleUser.photoUrl,
        createdAt: DateTime.now(),
      );
      await _db.collection('users').doc(uid).set(user.toJson());
      return user;
    }
    return AppUser.fromJson(doc.data()!);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(doc.data()!);
  }
}
