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
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    // Self-heal: if the user doc is missing (e.g. signup happened before rules
    // were deployed, or doc was deleted), back-fill a minimal user doc so the
    // rest of the app's UID-keyed reads work.
    await _ensureUserDoc(
      uid: cred.user!.uid,
      email: email,
      fallbackUsername: email.split('@').first.toLowerCase(),
      fallbackDisplayName: email.split('@').first,
    );
  }

  Future<void> _ensureUserDoc({
    required String uid,
    required String email,
    required String fallbackUsername,
    required String fallbackDisplayName,
    String? avatarUrl,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (doc.exists) return;
    final user = AppUser(
      uid: uid,
      username: fallbackUsername,
      displayName: fallbackDisplayName,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
    );
    await ref.set(user.toJson());
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
