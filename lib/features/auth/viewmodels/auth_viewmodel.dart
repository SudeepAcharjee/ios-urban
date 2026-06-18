import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../core/services/notification_service.dart';
import '../repositories/auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthViewModel extends AsyncNotifier<void> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final IAuthRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.watch(authRepositoryProvider);
    return null;
  }

  Future<void> sendOTP(String email) async {
    try {
      final String trimmedEmail = email.trim();
      if (trimmedEmail.isEmpty) {
        throw 'Please enter your email address';
      }
      await _repository.sendOTP(trimmedEmail);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> verifyOTP(String email, String otp) async {
    try {
      return await _repository.verifyOTP(email.trim(), otp.trim());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      final String trimmedEmail = email.trim();

      try {
        // 1. Authenticate with Firebase Auth
        final UserCredential userCredential = await _auth
            .signInWithEmailAndPassword(
              email: trimmedEmail,
              password: password.trim(),
            );

        // 2. Check if user exists in 'workers' or 'users' collection
        if (userCredential.user != null) {
          final String uid = userCredential.user!.uid;

          // Try fetching from workers first
          var doc = await _firestore.collection('workers').doc(uid).get();
          bool isWorker = doc.exists;

          if (!isWorker) {
            // Try fetching from users
            doc = await _firestore.collection('users').doc(uid).get();
          }

          if (!doc.exists) {
            await _auth.signOut();
            throw 'USER_NOT_FOUND_IN_FIRESTORE';
          }

          final data = doc.data();
          if (data?['status'] == 'Blocked') {
            await _auth.signOut();
            throw 'ACCOUNT_BLOCKED';
          }

          // 3. Save FCM Token on successful login
          final token = await NotificationService.getToken();
          final collectionName = isWorker ? 'workers' : 'users';
          await _firestore.collection(collectionName).doc(uid).update({
            'isOtpVerified': false,
            if (token != null) 'fcmToken': token,
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
        state = const AsyncData(null);
      } on FirebaseAuthException catch (e) {
        // If Auth fails, check if the email exists in Firestore at all
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // Check both collections by email
          final workerQuery = await _firestore
              .collection('workers')
              .where('email', isEqualTo: trimmedEmail)
              .get();
          if (workerQuery.docs.isEmpty) {
            final userQuery = await _firestore
                .collection('users')
                .where('email', isEqualTo: trimmedEmail)
                .get();
            if (userQuery.docs.isEmpty) {
              throw 'USER_NOT_FOUND_IN_FIRESTORE';
            }
          }
        }

        throw _getErrorMessage(e);
      }
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    bool isOtpVerified = true,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (email.isEmpty || password.isEmpty || name.isEmpty || phone.isEmpty) {
        throw 'Please fill all fields';
      }

      try {
        // Create User
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password.trim(),
            );

        // Save User Data to Firestore
        if (userCredential.user != null) {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
                'uid': userCredential.user!.uid,
                'name': name.trim(),
                'email': email.trim(),
                'phone': phone.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'role': 'user',
                'isOtpVerified': isOtpVerified,
              });
        }
      } on FirebaseAuthException catch (e) {
        throw _getErrorMessage(e);
      } catch (e) {
        throw 'An unexpected error occurred. Please try again.';
      }
    });
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. This device has been temporarily blocked. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (email.isEmpty) {
      throw 'Please enter your email address';
    }
    try {
      await _repository.sendPasswordResetEmail(email.trim());
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = _auth.currentUser;
      if (user != null) {
        final String uid = user.uid;

        // Check if user is in workers collection
        final workerDoc = await _firestore.collection('workers').doc(uid).get();
        final String collectionName = workerDoc.exists ? 'workers' : 'users';

        await _firestore.collection(collectionName).doc(uid).update(data);
      } else {
        throw 'User not authenticated';
      }
    });
  }

  // --- Phone Verification Logic ---

  String? _verificationId;

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification or instant verification (Android only)
          final currentUser = _auth.currentUser;
          if (currentUser == null) {
            onVerificationFailed(
              'No authenticated user available for phone verification.',
            );
            return;
          }
          await currentUser.linkWithCredential(credential);
          onVerificationCompleted();
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onVerificationFailed(e.toString());
    }
  }

  Future<void> verifySentCode(String smsCode) async {
    if (_verificationId == null) {
      throw 'Verification ID is missing. Please try sending the code again.';
    }

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No authenticated user available for phone verification.';
      }
      await currentUser.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw 'This phone number is already linked to another account.';
      }
      throw e.message ?? 'Invalid code. Please try again.';
    } catch (e) {
      throw 'An error occurred during verification: $e';
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await NotificationService.signOut();
      await _auth.signOut();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    });
  }

  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'User not authenticated';
      }
      final String uid = user.uid;

      // 1. Check if user is worker or regular user
      bool isWorker = false;
      try {
        final workerDoc = await _firestore
            .collection('workers')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        isWorker = workerDoc.exists;
      } catch (e) {
        debugPrint('Error checking worker status: $e');
      }

      // 2. Delete profile and subcollections
      if (isWorker) {
        try {
          final kycSnap = await _firestore
              .collection('workers')
              .doc(uid)
              .collection('kyc')
              .get()
              .timeout(const Duration(seconds: 4));
          for (final doc in kycSnap.docs) {
            await doc.reference.delete().timeout(const Duration(seconds: 2));
          }
        } catch (e) {
          debugPrint('Error deleting worker kyc subcollection: $e');
        }

        try {
          await _firestore
              .collection('kyc_submissions')
              .doc(uid)
              .delete()
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error deleting kyc submission: $e');
        }

        try {
          await _firestore
              .collection('workers')
              .doc(uid)
              .delete()
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error deleting worker document: $e');
        }
      } else {
        final subcollections = [
          'vehicles',
          'bookmarked',
          'payment',
          'cards',
          'addresses',
        ];
        for (final sub in subcollections) {
          try {
            final snap = await _firestore
                .collection('users')
                .doc(uid)
                .collection(sub)
                .get()
                .timeout(const Duration(seconds: 4));
            for (final doc in snap.docs) {
              await doc.reference.delete().timeout(const Duration(seconds: 2));
            }
          } catch (e) {
            debugPrint('Error deleting user subcollection $sub: $e');
          }
        }

        try {
          await _firestore
              .collection('users')
              .doc(uid)
              .delete()
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Error deleting user document: $e');
        }
      }

      // 3. Delete root level referenced documents
      // bookings
      try {
        final bookingsUserSnap = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: uid)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in bookingsUserSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error deleting user bookings: $e');
      }
      try {
        final bookingsWorkerSnap = await _firestore
            .collection('bookings')
            .where('workerId', isEqualTo: uid)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in bookingsWorkerSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error deleting worker bookings: $e');
      }

      // reviews
      try {
        final reviewsUserSnap = await _firestore
            .collection('reviews')
            .where('userId', isEqualTo: uid)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in reviewsUserSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error deleting user reviews: $e');
      }
      try {
        final reviewsWorkerSnap = await _firestore
            .collection('reviews')
            .where('workerId', isEqualTo: uid)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in reviewsWorkerSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error deleting worker reviews: $e');
      }

      // support
      try {
        final supportSnap = await _firestore
            .collection('support')
            .where('userId', isEqualTo: uid)
            .get()
            .timeout(const Duration(seconds: 4));
        for (final doc in supportSnap.docs) {
          await doc.reference.delete().timeout(const Duration(seconds: 2));
        }
      } catch (e) {
        debugPrint('Error deleting support docs: $e');
      }

      // 4. Delete Auth user record
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw 'This action is sensitive and requires recent authentication. Please log out, log back in, and try again.';
        }
        rethrow;
      }

      // 5. Clean up local auth session
      try {
        await _auth.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {}

      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }

  Future<void> signInWithGoogle({bool isRegistration = false}) async {
    state = const AsyncLoading();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Force a full sign-out to clear any stuck sessions
      await googleSignIn.signOut().catchError((_) => null);
      await googleSignIn.disconnect().catchError((_) => null);
      await Future.delayed(const Duration(milliseconds: 500));

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        state = const AsyncData(null);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      await _onSocialSignIn(userCredential, isRegistration: isRegistration);
      state = const AsyncData(null);
    } catch (e, stack) {
      debugPrint('GOOGLE_AUTH_ERROR: $e');

      String errorMessage = e.toString();
      if (errorMessage.contains('ApiException: 10')) {
        errorMessage =
            'Google Sign-In Error (10): Developer Error. This is caused by a missing or mismatched SHA-1 fingerprint for your new package name (com.urbanservices.app) in Firebase Console. Please add both your Debug and Release SHA-1 fingerprints to Firebase and update google-services.json.';
      }

      state = AsyncError(errorMessage, stack);
      throw errorMessage;
    }
  }

  Future<void> signInWithApple({bool isRegistration = false}) async {
    state = const AsyncLoading();
    try {
      final appleProvider = AppleAuthProvider();
      appleProvider.addScope('email');
      appleProvider.addScope('name');
      
      final UserCredential userCredential = await _auth.signInWithProvider(appleProvider);
      
      await _onSocialSignIn(userCredential, isRegistration: isRegistration);
      state = const AsyncData(null);
    } catch (e, stack) {
      debugPrint('APPLE_AUTH_ERROR: $e');
      state = AsyncError(e.toString(), stack);
      throw e.toString();
    }
  }

  Future<void> _onSocialSignIn(
    UserCredential userCredential, {
    bool isRegistration = false,
  }) async {
    if (userCredential.user != null) {
      final user = userCredential.user!;

      // Check workers collection first
      var doc = await _firestore.collection('workers').doc(user.uid).get();
      bool isWorker = doc.exists;

      if (!isWorker) {
        // Check users collection
        doc = await _firestore.collection('users').doc(user.uid).get();
      }

      if (doc.exists && doc.data()?['status'] == 'Blocked') {
        await _auth.signOut();
        try {
          await GoogleSignIn().signOut();
        } catch (_) {}
        throw 'ACCOUNT_BLOCKED';
      }

      if (!doc.exists) {
        if (!isRegistration) {
          await _auth.signOut();
          try {
            await GoogleSignIn().signOut();
          } catch (_) {}
          throw 'USER_NOT_FOUND_IN_FIRESTORE';
        } else {
          // Default registration is always for 'user' role
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? '',
            'profilePic': user.photoURL ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'role': 'user',
            'isOtpVerified': false,
          });
          // Re-fetch doc after creation
          doc = await _firestore.collection('users').doc(user.uid).get();
        }
      }

      // Save FCM Token to whichever collection the user belongs to
      final token = await NotificationService.getToken();
      final collectionName = isWorker ? 'workers' : 'users';
      await _firestore.collection(collectionName).doc(user.uid).update({
        'isOtpVerified': false,
        if (token != null) 'fcmToken': token,
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, void>(
  AuthViewModel.new,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }

      return Stream.multi((controller) {
        StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
        final workerSub = FirebaseFirestore.instance
            .collection('workers')
            .doc(user.uid)
            .snapshots()
            .listen((workerSnap) {
              if (workerSnap.exists) {
                userSub?.cancel();
                userSub = null;
                controller.add(workerSnap.data());
              } else {
                userSub ??= FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots()
                    .listen((userSnap) {
                      controller.add(userSnap.data());
                    });
              }
            }, onError: controller.addError);

        ref.onDispose(() {
          workerSub.cancel();
          userSub?.cancel();
        });
      });
    },
    loading: () => Stream.value(null),
    error: (error, stackTrace) {
      return Stream.value(null);
    },
  );
});
