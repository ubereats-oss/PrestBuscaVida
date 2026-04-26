import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  // ── E-MAIL ──────────────────────────────────────────────────────────────
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    final existing = await _getUserDocument(user.uid);
    if (existing != null) return existing;
    // Documento ausente (cadastro incompleto anterior) — cria automaticamente.
    final role = await _claimAdminIfFirst(user.uid);
    return _createUserDocument(
      user,
      role: role,
      displayName: user.displayName ?? email.split('@').first,
    );
  }

  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName);
    final role = await _claimAdminIfFirst(user.uid);
    return _createUserDocument(user, role: role, displayName: displayName);
  }

  // ── TELEFONE ──────────────────────────────────────────────────────────────
  /// Passo 1: enviar SMS.
  /// O número deve estar no formato E.164, ex: +5511999998888
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required String displayName,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    required void Function(UserModel user) onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android: verificação automática sem digitar o código
        final result = await _auth.signInWithCredential(credential);
        final user = result.user!;
        final existing = await _getUserDocument(user.uid);
        if (existing != null) {
          onAutoVerified(existing);
          return;
        }
        final role = await _claimAdminIfFirst(user.uid);
        final userModel = await _createUserDocument(
          user,
          role: role,
          displayName: displayName,
        );
        onAutoVerified(userModel);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Erro ao verificar o telefone.');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Passo 2: validar o código SMS digitado pelo usuário.
  Future<UserModel> signInWithPhoneCode({
    required String verificationId,
    required String smsCode,
    required String displayName,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user!;
    // Usuário já tinha conta → apenas retorna o documento existente
    final existing = await _getUserDocument(user.uid);
    if (existing != null) return existing;
    // Novo usuário
    final role = await _claimAdminIfFirst(user.uid);
    return _createUserDocument(user, role: role, displayName: displayName);
  }

  // ── GERAL ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? email,
    String? phone,
    String? gleba,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'displayName': displayName,
      if (email != null) 'email': email,
      'phone': phone,
      'gleba': gleba,
    });
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      await fbUser.updateDisplayName(displayName);
    }
  }

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _getUserDocument(user.uid);
  }

  // ── PRIVADOS ──────────────────────────────────────────────────────────────
  /// Usa um contador atômico em 'meta/stats' para garantir que somente o
  /// primeiro usuário a se cadastrar receba role 'admin', sem race condition.
  Future<String> _claimAdminIfFirst(String uid) async {
    try {
      final statsRef = _firestore.collection('meta').doc('stats');
      String role = 'user';
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(statsRef);
        final count =
            snap.exists ? (snap.data()!['userCount'] ?? 0) as int : 0;
        if (count == 0) {
          role = 'admin';
        }
        transaction.set(
          statsRef,
          {'userCount': count + 1},
          SetOptions(merge: true),
        );
      });
      return role;
    } catch (_) {
      // Se a transação falhar (ex: regras do Firestore), continua com role 'user'
      // para garantir que o documento do usuário seja criado mesmo assim.
      return 'user';
    }
  }

  Future<UserModel> _createUserDocument(
    User firebaseUser, {
    required String role,
    required String displayName,
  }) async {
    final name = displayName.isNotEmpty
        ? displayName
        : (firebaseUser.displayName ?? firebaseUser.phoneNumber ?? 'Usuário');
    final userModel = UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      phone: firebaseUser.phoneNumber,
      displayName: name,
      role: role,
      createdAt: DateTime.now(),
    );
    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userModel.toMap());
    return userModel;
  }

  Future<UserModel?> _getUserDocument(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, uid: uid);
  }

  Future<void> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final result = await _auth.signInWithCredential(oauthCredential);
    final user = result.user!;

    // Apple only sends name on the very first sign-in; persist it if present.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    final appleDisplayName = (givenName != null || familyName != null)
        ? '${givenName ?? ''} ${familyName ?? ''}'.trim()
        : null;

    if (appleDisplayName != null && appleDisplayName.isNotEmpty) {
      await user.updateDisplayName(appleDisplayName);
    }

    final existing = await _getUserDocument(user.uid);
    if (existing != null) return;

    final role = await _claimAdminIfFirst(user.uid);
    final displayName = appleDisplayName?.isNotEmpty == true
        ? appleDisplayName!
        : user.displayName ?? user.email ?? 'Usuário Apple';
    await _createUserDocument(user, role: role, displayName: displayName);
  }
}
