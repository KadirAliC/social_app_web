import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
      final user = userCredential.user;

      if (user != null) {
        await _firestore.collection('business_users').doc(user.uid).set({
          'business_email': user.email,
          'business_name': user.displayName,
          'business_image_path': user.photoURL,
          'business_create_date': DateTime.now(),
          'last_login': DateTime.now(),
        }, SetOptions(merge: true));
      }

      return userCredential;
    } catch (e) {
      print('Google Sign In Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}