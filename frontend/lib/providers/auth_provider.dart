/// SMARTCARE+ Authentication Provider
///
/// Riverpod-based auth state management with Firebase Authentication
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// User role enum
enum UserRole { elderly, caregiver, guardian, admin }

/// User profile model
class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String? phone;
  final UserRole role;
  final String? profileImageUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? elderlyProfile;
  final Map<String, dynamic>? guardianProfile;

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    this.phone,
    required this.role,
    this.profileImageUrl,
    required this.createdAt,
    this.elderlyProfile,
    this.guardianProfile,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'],
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.elderly,
      ),
      profileImageUrl: data['profile_image_url'],
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      elderlyProfile: data['elderly_profile'],
      guardianProfile: data['guardian_profile'],
    );
  }

  bool get isGuardian => role == UserRole.guardian || role == UserRole.admin;
  bool get isElderly => role == UserRole.elderly;
  bool get isCaregiver => role == UserRole.caregiver;
}

/// Authentication state
class AuthState {
  final User? firebaseUser;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.firebaseUser,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => firebaseUser != null;
  bool get hasProfile => profile != null;

  AuthState copyWith({
    User? firebaseUser,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      firebaseUser: firebaseUser ?? this.firebaseUser,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadUserProfile(user);
      } else {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadUserProfile(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        state = AuthState(
          firebaseUser: user,
          profile: UserProfile.fromFirestore(doc),
        );
      } else {
        state = AuthState(firebaseUser: user);
      }
    } catch (e) {
      state = AuthState(
        firebaseUser: user,
        error: 'Failed to load profile: $e',
      );
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getAuthErrorMessage(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Sign in with Google
  /// Returns: null if cancelled, true if existing user, false if new user (needs role selection)
  Future<bool?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User cancelled the sign-in
        state = state.copyWith(isLoading: false);
        return null;
      }
      
      // Obtain auth details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Failed to sign in with Google');
      }
      
      // Check if user profile exists in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        // New user - DON'T create profile yet, let them choose role
        state = AuthState(
          firebaseUser: userCredential.user,
          isLoading: false,
        );
        return false; // Indicates new user needs role selection
      }
      
      // Existing user - load profile
      await _loadUserProfile(userCredential.user!);
      
      return true; // Indicates existing user with profile
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getAuthErrorMessage(e.code),
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Google sign-in failed: ${e.toString()}',
      );
      return null;
    }
  }
  
  /// Complete profile for new Google user
  Future<bool> completeGoogleSignUp({required UserRole role}) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'No authenticated user');
      return false;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Create profile in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': user.displayName ?? 'User',
        'role': role.name,
        'profile_image_url': user.photoURL,
        'auth_provider': 'google',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Load user profile
      await _loadUserProfile(user);
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create profile: $e',
      );
      return false;
    }
  }

  /// Register with email and password
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (credential.user == null) {
        throw Exception('Failed to create user');
      }
      
      // Update display name
      await credential.user!.updateDisplayName(name);
      
      // Create user profile in Firestore
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'name': name,
        'role': role.name,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Reload to trigger auth state change
      await _loadUserProfile(credential.user!);
      
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getAuthErrorMessage(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // Sign out from Google if signed in
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
    state = const AuthState();
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to send reset email');
      return false;
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    Map<String, dynamic>? elderlyProfile,
    Map<String, dynamic>? guardianProfile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'No authenticated user');
      return false;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (elderlyProfile != null) updates['elderly_profile'] = elderlyProfile;
      if (guardianProfile != null) updates['guardian_profile'] = guardianProfile;
      
      await _firestore.collection('users').doc(user.uid).update(updates);
      
      // Reload profile
      await _loadUserProfile(user);
      
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: $e',
      );
      return false;
    }
  }

  /// Get Firebase ID token for API calls
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      default:
        return 'Authentication failed. Please try again';
    }
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).firebaseUser;
});

/// Convenience provider for user profile
final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).profile;
});

/// Convenience provider for auth loading state
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});
