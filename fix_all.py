"""
Script de correção completa — PrestServ Busca Vida
Executa: py fix_all.py  (já dentro da pasta raiz do projeto)
"""

import os, sys, textwrap

# ─── helpers ────────────────────────────────────────────────────────────────

def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    print(f"  ✅  {path}")

def check_not_firebase_options(path):
    if "firebase_options" in path:
        print(f"  🚫  IGNORADO (firebase_options protegido): {path}")
        sys.exit(1)

BASE = "lib"

# ════════════════════════════════════════════════════════════════════════════
# 1. categories_repository.dart
#    - Remove sort-por-nome duplicado em fetchActiveCategories (mantém orderBy Firestore)
#    - watchActiveCategories já estava correto (sem sort extra) — mantém
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "data", "repositories", "categories_repository.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:cloud_firestore/cloud_firestore.dart';
    import '../models/category_model.dart';

    class CategoriesRepository {
      final FirebaseFirestore _firestore;

      CategoriesRepository({
        FirebaseFirestore? firestore,
      }) : _firestore = firestore ?? FirebaseFirestore.instance;

      /// Retorna categorias ativas ordenadas pelo campo [order] (definido no Firestore).
      Future<List<CategoryModel>> fetchActiveCategories() async {
        final snapshot = await _firestore
            .collection('categories')
            .where('isActive', isEqualTo: true)
            .orderBy('order')
            .get();
        return snapshot.docs.map((doc) {
          return CategoryModel.fromMap(doc.data(), id: doc.id);
        }).toList();
      }

      /// Stream de categorias ativas ordenadas pelo campo [order].
      Stream<List<CategoryModel>> watchActiveCategories() {
        return _firestore
            .collection('categories')
            .where('isActive', isEqualTo: true)
            .orderBy('order')
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CategoryModel.fromMap(doc.data(), id: doc.id);
          }).toList();
        });
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 2. reviews_repository.dart
#    - Substitui leitura+escrita sequencial por runTransaction (atomicidade)
#    - Elimina race condition no cálculo de avgRating / ratingCount
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "data", "repositories", "reviews_repository.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:cloud_firestore/cloud_firestore.dart';
    import '../models/review_model.dart';

    class ReviewsRepository {
      final FirebaseFirestore _firestore;

      ReviewsRepository({
        FirebaseFirestore? firestore,
      }) : _firestore = firestore ?? FirebaseFirestore.instance;

      Stream<List<ReviewModel>> watchReviewsByProvider(String providerId) {
        return _firestore
            .collection('reviews')
            .where('providerId', isEqualTo: providerId)
            .snapshots()
            .map((snapshot) {
          final reviews = snapshot.docs.map((doc) {
            return ReviewModel.fromMap(doc.data(), id: doc.id);
          }).toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
      }

      /// Salva a avaliação e recalcula [avgRating] / [ratingCount] atomicamente
      /// via [runTransaction], eliminando a race condition de escrita concorrente.
      Future<void> addReview({required ReviewModel review}) async {
        final reviewRef = _firestore.collection('reviews').doc();
        final providerRef =
            _firestore.collection('providers').doc(review.providerId);

        await _firestore.runTransaction((transaction) async {
          final providerSnap = await transaction.get(providerRef);

          // Grava a avaliação
          transaction.set(reviewRef, review.toMap());

          // Atualiza o prestador somente se o documento existir
          if (providerSnap.exists) {
            final data = providerSnap.data()!;
            final currentCount = (data['ratingCount'] ?? 0) as int;
            final currentAvg = _toDouble(data['avgRating']);
            final newCount = currentCount + 1;
            final newAvg =
                ((currentAvg * currentCount) + review.rating) / newCount;

            transaction.update(providerRef, {
              'ratingCount': newCount,
              'avgRating': double.parse(newAvg.toStringAsFixed(1)),
            });
          }
        });
      }

      static double _toDouble(dynamic value) {
        if (value is int) return value.toDouble();
        if (value is double) return value;
        return double.tryParse(value.toString()) ?? 0;
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 3. auth_repository.dart
#    - _isFirstUser usa transaction para evitar race condition na atribuição de admin
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "data", "repositories", "auth_repository.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import '../models/user_model.dart';

    class AuthRepository {
      final FirebaseAuth _auth;
      final FirebaseFirestore _firestore;

      AuthRepository({
        FirebaseAuth? auth,
        FirebaseFirestore? firestore,
      })  : _auth = auth ?? FirebaseAuth.instance,
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
        final userModel = await _getUserDocument(credential.user!.uid);
        if (userModel == null) {
          throw Exception('Usuário não encontrado. Crie uma conta primeiro.');
        }
        return userModel;
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

      Future<UserModel?> getCurrentUserModel() async {
        final user = _auth.currentUser;
        if (user == null) return null;
        return _getUserDocument(user.uid);
      }

      // ── PRIVADOS ──────────────────────────────────────────────────────────────

      /// Usa um contador atômico em 'meta/stats' para garantir que somente o
      /// primeiro usuário a se cadastrar receba role 'admin', sem race condition.
      Future<String> _claimAdminIfFirst(String uid) async {
        final statsRef = _firestore.collection('meta').doc('stats');
        String role = 'user';

        await _firestore.runTransaction((transaction) async {
          final snap = await transaction.get(statsRef);
          final count = snap.exists ? (snap.data()!['userCount'] ?? 0) as int : 0;
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
      }

      Future<UserModel> _createUserDocument(
        User firebaseUser, {
        required String role,
        required String displayName,
      }) async {
        final name = displayName.isNotEmpty
            ? displayName
            : (firebaseUser.displayName ??
                firebaseUser.phoneNumber ??
                'Usuário');
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
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 4. review_model.dart
#    - Adiciona campo reviewerUid para vincular avaliação ao usuário
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "data", "models", "review_model.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:cloud_firestore/cloud_firestore.dart';

    class ReviewModel {
      final String id;
      final String providerId;
      final String reviewerUid;
      final String reviewerName;
      final int rating;
      final String comment;
      final DateTime createdAt;

      const ReviewModel({
        required this.id,
        required this.providerId,
        required this.reviewerUid,
        required this.reviewerName,
        required this.rating,
        required this.comment,
        required this.createdAt,
      });

      factory ReviewModel.fromMap(
        Map<String, dynamic> map, {
        required String id,
      }) {
        return ReviewModel(
          id: id,
          providerId: (map['providerId'] ?? '').toString(),
          reviewerUid: (map['reviewerUid'] ?? '').toString(),
          reviewerName: (map['reviewerName'] ?? '').toString(),
          rating: (map['rating'] ?? 1) as int,
          comment: (map['comment'] ?? '').toString(),
          createdAt:
              (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }

      Map<String, dynamic> toMap() {
        return {
          'providerId': providerId,
          'reviewerUid': reviewerUid,
          'reviewerName': reviewerName,
          'rating': rating,
          'comment': comment,
          'createdAt': Timestamp.fromDate(createdAt),
        };
      }

      ReviewModel copyWith({
        String? id,
        String? providerId,
        String? reviewerUid,
        String? reviewerName,
        int? rating,
        String? comment,
        DateTime? createdAt,
      }) {
        return ReviewModel(
          id: id ?? this.id,
          providerId: providerId ?? this.providerId,
          reviewerUid: reviewerUid ?? this.reviewerUid,
          reviewerName: reviewerName ?? this.reviewerName,
          rating: rating ?? this.rating,
          comment: comment ?? this.comment,
          createdAt: createdAt ?? this.createdAt,
        );
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 5. review_form_page.dart
#    - Passa reviewerUid ao criar ReviewModel
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "features", "reviews", "review_form_page.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:flutter/material.dart';
    import '../../data/models/review_model.dart';
    import '../../data/models/user_model.dart';
    import '../../data/repositories/reviews_repository.dart';

    class ReviewFormPage extends StatefulWidget {
      final String providerId;
      final String providerName;
      final UserModel currentUser;

      const ReviewFormPage({
        super.key,
        required this.providerId,
        required this.providerName,
        required this.currentUser,
      });

      @override
      State<ReviewFormPage> createState() => _ReviewFormPageState();
    }

    class _ReviewFormPageState extends State<ReviewFormPage> {
      final _commentController = TextEditingController();
      final _reviewsRepository = ReviewsRepository();
      int _rating = 0;
      bool _isLoading = false;
      String? _errorMessage;

      @override
      void dispose() {
        _commentController.dispose();
        super.dispose();
      }

      Future<void> _submit() async {
        if (_rating == 0) {
          setState(() => _errorMessage = 'Selecione uma nota de 1 a 5 estrelas.');
          return;
        }
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        try {
          final review = ReviewModel(
            id: '',
            providerId: widget.providerId,
            reviewerUid: widget.currentUser.uid,
            reviewerName: widget.currentUser.displayName,
            rating: _rating,
            comment: _commentController.text.trim(),
            createdAt: DateTime.now(),
          );
          await _reviewsRepository.addReview(review: review);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Avaliação enviada. Obrigado!')),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            setState(() => _errorMessage = 'Erro ao enviar. Tente novamente.');
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Avaliar prestador'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.providerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sua nota',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      icon: Icon(
                        star <= _rating ? Icons.star : Icons.star_border,
                        size: 40,
                        color: Colors.amber,
                      ),
                      onPressed: () => setState(() => _rating = star),
                    );
                  }),
                ),
                if (_rating > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    _ratingLabel(_rating),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Comentário (opcional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar avaliação'),
                ),
              ],
            ),
          ),
        );
      }

      String _ratingLabel(int rating) {
        switch (rating) {
          case 1:
            return 'Ruim';
          case 2:
            return 'Regular';
          case 3:
            return 'Bom';
          case 4:
            return 'Muito bom';
          case 5:
            return 'Excelente';
          default:
            return '';
        }
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 6. suggest_provider_page.dart
#    - Troca .first.then sem tratamento de erro por Future cacheado em initState
#      com try/catch e mensagem de erro ao usuário
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "features", "suggestions", "suggest_provider_page.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:flutter/material.dart';
    import '../../data/models/category_model.dart';
    import '../../data/models/provider_model.dart';
    import '../../data/models/user_model.dart';
    import '../../data/repositories/categories_repository.dart';
    import '../../data/repositories/providers_repository.dart';

    class SuggestProviderPage extends StatefulWidget {
      final UserModel currentUser;

      const SuggestProviderPage({super.key, required this.currentUser});

      @override
      State<SuggestProviderPage> createState() => _SuggestProviderPageState();
    }

    class _SuggestProviderPageState extends State<SuggestProviderPage> {
      final _nameController = TextEditingController();
      final _phoneController = TextEditingController();
      final _whatsappController = TextEditingController();
      final _descriptionController = TextEditingController();
      final _providersRepository = ProvidersRepository();
      final _categoriesRepository = CategoriesRepository();

      CategoryModel? _selectedCategory;
      List<CategoryModel> _categories = [];
      bool _isLoading = false;
      bool _loadingCategories = true;
      String? _errorMessage;
      String? _categoriesError;

      @override
      void initState() {
        super.initState();
        _loadCategories();
      }

      Future<void> _loadCategories() async {
        try {
          final cats =
              await _categoriesRepository.fetchActiveCategories();
          if (mounted) {
            setState(() {
              _categories = cats;
              _loadingCategories = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _categoriesError =
                  'Não foi possível carregar as categorias. Tente novamente.';
              _loadingCategories = false;
            });
          }
        }
      }

      @override
      void dispose() {
        _nameController.dispose();
        _phoneController.dispose();
        _whatsappController.dispose();
        _descriptionController.dispose();
        super.dispose();
      }

      Future<void> _submit() async {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() => _errorMessage = 'Informe o nome do prestador.');
          return;
        }
        if (_selectedCategory == null) {
          setState(() => _errorMessage = 'Selecione uma categoria.');
          return;
        }
        if (_phoneController.text.trim().isEmpty &&
            _whatsappController.text.trim().isEmpty) {
          setState(
            () => _errorMessage =
                'Informe ao menos um contato (telefone ou WhatsApp).',
          );
          return;
        }
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        try {
          final provider = ProviderModel(
            id: '',
            name: name,
            categoryId: _selectedCategory!.id,
            categoryName: _selectedCategory!.name,
            phone: _phoneController.text.trim(),
            whatsapp: _whatsappController.text.trim(),
            description: _descriptionController.text.trim(),
            avgRating: 0,
            ratingCount: 0,
            isActive: false,
            status: 'pending',
            suggestedBy: widget.currentUser.uid,
          );
          await _providersRepository.suggestProvider(provider: provider);
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sugestão enviada!'),
                content: const Text(
                  'Obrigado! Sua sugestão foi recebida e será analisada pelo nosso time. '
                  'Assim que aprovada, o prestador aparecerá no app.',
                ),
                actions: [
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _errorMessage = 'Erro ao enviar. Tente novamente.');
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sugerir prestador')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Conhece um bom prestador de serviço? Indique aqui!',
                  style: TextStyle(fontSize: 16),
                ),
                const Text(
                  'Sua sugestão será revisada e, se aprovada, aparecerá no app.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do prestador *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                if (_loadingCategories)
                  const Center(child: CircularProgressIndicator())
                else if (_categoriesError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _categoriesError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _loadingCategories = true;
                            _categoriesError = null;
                          });
                          _loadCategories();
                        },
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Categoria *',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButton<CategoryModel>(
                      value: _selectedCategory,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: const Text('Selecione'),
                      items: _categories
                          .map(
                            (cat) => DropdownMenuItem(
                                value: cat, child: Text(cat.name)),
                          )
                          .toList(),
                      onChanged: (cat) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _whatsappController,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp (somente números com DDD)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'O que esse prestador faz?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar sugestão'),
                ),
              ],
            ),
          ),
        );
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 7. admin_panel_page.dart
#    - (_, _) → (_, __) em separatorBuilder
#    - _loadCategories: .first.then sem erro → fetchActiveCategories com try/catch
#    - _PendingTab: converte para StatefulWidget para uso seguro de mounted
#    - AdminPanelPage verifica role internamente
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "features", "admin", "admin_panel_page.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
    import 'package:flutter/material.dart';
    import '../../data/models/category_model.dart';
    import '../../data/models/provider_model.dart';
    import '../../data/repositories/auth_repository.dart';
    import '../../data/repositories/categories_repository.dart';
    import '../../data/repositories/providers_repository.dart';

    class AdminPanelPage extends StatefulWidget {
      const AdminPanelPage({super.key});

      @override
      State<AdminPanelPage> createState() => _AdminPanelPageState();
    }

    class _AdminPanelPageState extends State<AdminPanelPage>
        with SingleTickerProviderStateMixin {
      late final TabController _tabController;
      final _providersRepository = ProvidersRepository();
      final _categoriesRepository = CategoriesRepository();
      final _authRepository = AuthRepository();

      bool _authorized = false;
      bool _checkingAuth = true;

      @override
      void initState() {
        super.initState();
        _tabController = TabController(length: 2, vsync: this);
        _checkRole();
      }

      Future<void> _checkRole() async {
        final user = await _authRepository.getCurrentUserModel();
        if (mounted) {
          setState(() {
            _authorized = user?.isAdmin ?? false;
            _checkingAuth = false;
          });
        }
      }

      @override
      void dispose() {
        _tabController.dispose();
        super.dispose();
      }

      @override
      Widget build(BuildContext context) {
        if (_checkingAuth) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_authorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso negado')),
            body: const Center(
              child: Text('Você não tem permissão para acessar esta área.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Painel de administração'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Sugestões pendentes'),
                Tab(text: 'Adicionar prestador'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PendingTab(providersRepository: _providersRepository),
              _AddProviderTab(
                providersRepository: _providersRepository,
                categoriesRepository: _categoriesRepository,
              ),
            ],
          ),
        );
      }
    }

    // ── ABA: SUGESTÕES PENDENTES ──────────────────────────────────────────────

    class _PendingTab extends StatefulWidget {
      final ProvidersRepository providersRepository;

      const _PendingTab({required this.providersRepository});

      @override
      State<_PendingTab> createState() => _PendingTabState();
    }

    class _PendingTabState extends State<_PendingTab> {
      Future<void> _approve(ProviderModel provider) async {
        await widget.providersRepository.approveProvider(provider.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${provider.name} aprovado com sucesso.')),
          );
        }
      }

      Future<void> _reject(ProviderModel provider) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rejeitar sugestão'),
            content: Text('Deseja rejeitar "${provider.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rejeitar'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await widget.providersRepository.rejectProvider(provider.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${provider.name} rejeitado.')),
            );
          }
        }
      }

      @override
      Widget build(BuildContext context) {
        return StreamBuilder<List<ProviderModel>>(
          stream: widget.providersRepository.watchPendingProviders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro: ${snapshot.error}'));
            }
            final pending = snapshot.data ?? [];
            if (pending.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhuma sugestão pendente.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: pending.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final provider = pending[index];
                return ListTile(
                  title: Text(provider.name),
                  subtitle: Text(
                    '${provider.categoryName.isNotEmpty ? provider.categoryName : provider.categoryId}'
                    '${provider.description.isNotEmpty ? '\\n${provider.description}' : ''}',
                  ),
                  isThreeLine: provider.description.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        color: Colors.green,
                        tooltip: 'Aprovar',
                        onPressed: () => _approve(provider),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        color: Colors.red,
                        tooltip: 'Rejeitar',
                        onPressed: () => _reject(provider),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      }
    }

    // ── ABA: ADICIONAR PRESTADOR ──────────────────────────────────────────────

    class _AddProviderTab extends StatefulWidget {
      final ProvidersRepository providersRepository;
      final CategoriesRepository categoriesRepository;

      const _AddProviderTab({
        required this.providersRepository,
        required this.categoriesRepository,
      });

      @override
      State<_AddProviderTab> createState() => _AddProviderTabState();
    }

    class _AddProviderTabState extends State<_AddProviderTab> {
      final _nameController = TextEditingController();
      final _phoneController = TextEditingController();
      final _whatsappController = TextEditingController();
      final _descriptionController = TextEditingController();

      CategoryModel? _selectedCategory;
      List<CategoryModel> _categories = [];
      bool _isLoading = false;
      bool _loadingCategories = true;
      String? _errorMessage;
      String? _categoriesError;

      @override
      void initState() {
        super.initState();
        _loadCategories();
      }

      @override
      void dispose() {
        _nameController.dispose();
        _phoneController.dispose();
        _whatsappController.dispose();
        _descriptionController.dispose();
        super.dispose();
      }

      Future<void> _loadCategories() async {
        try {
          final cats =
              await widget.categoriesRepository.fetchActiveCategories();
          if (mounted) {
            setState(() {
              _categories = cats;
              _loadingCategories = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _categoriesError =
                  'Não foi possível carregar as categorias. Tente novamente.';
              _loadingCategories = false;
            });
          }
        }
      }

      Future<void> _submit() async {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          setState(() => _errorMessage = 'Informe o nome do prestador.');
          return;
        }
        if (_selectedCategory == null) {
          setState(() => _errorMessage = 'Selecione uma categoria.');
          return;
        }
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
        try {
          final provider = ProviderModel(
            id: '',
            name: name,
            categoryId: _selectedCategory!.id,
            categoryName: _selectedCategory!.name,
            phone: _phoneController.text.trim(),
            whatsapp: _whatsappController.text.trim(),
            description: _descriptionController.text.trim(),
            avgRating: 0,
            ratingCount: 0,
            isActive: true,
            status: 'active',
          );
          await widget.providersRepository.addProvider(provider: provider);
          if (mounted) {
            _nameController.clear();
            _phoneController.clear();
            _whatsappController.clear();
            _descriptionController.clear();
            setState(() => _selectedCategory = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Prestador adicionado com sucesso!')),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() => _errorMessage = 'Erro ao salvar. Tente novamente.');
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }

      @override
      Widget build(BuildContext context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do prestador *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              if (_loadingCategories)
                const Center(child: CircularProgressIndicator())
              else if (_categoriesError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _categoriesError!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _loadingCategories = true;
                          _categoriesError = null;
                        });
                        _loadCategories();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButton<CategoryModel>(
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Selecione'),
                    items: _categories
                        .map(
                          (cat) => DropdownMenuItem(
                              value: cat, child: Text(cat.name)),
                        )
                        .toList(),
                    onChanged: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (somente números com DDD)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição dos serviços',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Adicionar prestador'),
              ),
            ],
          ),
        );
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 8. providers_page.dart
#    - (_, _) → (_, __) em separatorBuilder
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "features", "providers", "providers_page.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:flutter/material.dart';
    import '../../data/models/provider_model.dart';
    import '../../data/repositories/providers_repository.dart';
    import '../provider_detail/provider_detail_page.dart';

    class ProvidersPage extends StatefulWidget {
      final String categoryName;
      final String? categoryId;
      final String? searchQuery;

      const ProvidersPage({
        super.key,
        required this.categoryName,
        this.categoryId,
        this.searchQuery,
      });

      @override
      State<ProvidersPage> createState() => _ProvidersPageState();
    }

    class _ProvidersPageState extends State<ProvidersPage> {
      final _repository = ProvidersRepository();
      late final Stream<List<ProviderModel>> _stream;

      @override
      void initState() {
        super.initState();
        _stream = _buildStream();
      }

      Stream<List<ProviderModel>> _buildStream() {
        final normalizedSearch = widget.searchQuery?.trim() ?? '';
        if (normalizedSearch.isNotEmpty) {
          return _repository.watchProvidersForSearch(
            searchQuery: normalizedSearch,
          );
        }
        final normalizedCategoryId = widget.categoryId?.trim() ?? '';
        if (normalizedCategoryId.isNotEmpty) {
          return _repository.watchProvidersByCategory(
            categoryId: normalizedCategoryId,
          );
        }
        return _repository.watchProvidersForSearch(searchQuery: '');
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.categoryName),
          ),
          body: StreamBuilder<List<ProviderModel>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Erro ao carregar prestadores:\\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final providers = snapshot.data ?? [];
              if (providers.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhum prestador encontrado.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: providers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  final hasDescription = provider.description.isNotEmpty;
                  final ratingLine =
                      'Nota: ${provider.avgRating.toStringAsFixed(1)} '
                      '(${provider.ratingCount} avaliações)';
                  return ListTile(
                    title: Text(provider.name),
                    subtitle: Text(
                      hasDescription
                          ? '${provider.description}\\n$ratingLine'
                          : ratingLine,
                    ),
                    isThreeLine: hasDescription,
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailPage(
                            provider: provider,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      }
    }
"""))

# ════════════════════════════════════════════════════════════════════════════
# 9. provider_detail_page.dart
#    - (_, _) → (_, __) em separatorBuilder
# ════════════════════════════════════════════════════════════════════════════
path = os.path.join(BASE, "features", "provider_detail", "provider_detail_page.dart")
check_not_firebase_options(path)
write(path, textwrap.dedent("""\
    import 'package:flutter/material.dart';
    import 'package:url_launcher/url_launcher.dart';
    import '../../data/models/provider_model.dart';
    import '../../data/models/review_model.dart';
    import '../../data/models/user_model.dart';
    import '../../data/repositories/auth_repository.dart';
    import '../../data/repositories/reviews_repository.dart';
    import '../reviews/review_form_page.dart';

    class ProviderDetailPage extends StatefulWidget {
      final ProviderModel provider;

      const ProviderDetailPage({
        super.key,
        required this.provider,
      });

      @override
      State<ProviderDetailPage> createState() => _ProviderDetailPageState();
    }

    class _ProviderDetailPageState extends State<ProviderDetailPage> {
      final _reviewsRepository = ReviewsRepository();
      final _authRepository = AuthRepository();
      UserModel? _currentUser;

      @override
      void initState() {
        super.initState();
        _authRepository.getCurrentUserModel().then((user) {
          if (mounted) setState(() => _currentUser = user);
        });
      }

      Future<void> _openWhatsApp() async {
        final number =
            widget.provider.whatsapp.replaceAll(RegExp(r'\\D'), '');
        final uri = Uri.parse('https://wa.me/55$number');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Não foi possível abrir o WhatsApp.')),
            );
          }
        }
      }

      Future<void> _makePhoneCall() async {
        final number =
            widget.provider.phone.replaceAll(RegExp(r'\\D'), '');
        final uri = Uri.parse('tel:$number');
        if (!await launchUrl(uri)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Não foi possível iniciar a ligação.')),
            );
          }
        }
      }

      void _openReviewForm() {
        if (_currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Faça login para avaliar.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewFormPage(
              providerId: widget.provider.id,
              providerName: widget.provider.name,
              currentUser: _currentUser!,
            ),
          ),
        );
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.provider.name),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.provider.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.provider.categoryName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.provider.categoryName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (widget.provider.description.isNotEmpty) ...[
                  Text(
                    widget.provider.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.provider.phone.isNotEmpty) ...[
                  Text(
                    'Telefone: ${widget.provider.phone}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                ],
                if (widget.provider.whatsapp.isNotEmpty) ...[
                  Text(
                    'WhatsApp: ${widget.provider.whatsapp}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.provider.avgRating.toStringAsFixed(1)}  '
                      '(${widget.provider.ratingCount} avaliações)',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (widget.provider.whatsapp.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat),
                      label: const Text('Falar no WhatsApp'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.provider.phone.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _makePhoneCall,
                      icon: const Icon(Icons.phone),
                      label: const Text('Ligar agora'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openReviewForm,
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Avaliar prestador'),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Avaliações',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<ReviewModel>>(
                  stream: _reviewsRepository
                      .watchReviewsByProvider(widget.provider.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final reviews = snapshot.data ?? [];
                    if (reviews.isEmpty) {
                      return const Text(
                        'Nenhuma avaliação ainda. Seja o primeiro!',
                        style: TextStyle(color: Colors.grey),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final review = reviews[index];
                        return _ReviewTile(review: review);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }
    }

    class _ReviewTile extends StatelessWidget {
      final ReviewModel review;

      const _ReviewTile({required this.review});

      @override
      Widget build(BuildContext context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < review.rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  review.reviewerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review.comment),
            ],
            const SizedBox(height: 2),
            Text(
              _formatDate(review.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      }

      String _formatDate(DateTime date) {
        return '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}';
      }
    }
"""))

print()
print("=" * 60)
print("✅  Todas as correções aplicadas com sucesso!")
print("=" * 60)
print()
print("Resumo das alterações:")
print("  1. categories_repository.dart  — sort duplicado removido")
print("  2. reviews_repository.dart     — race condition → runTransaction")
print("  3. auth_repository.dart        — race condition admin → transaction")
print("  4. review_model.dart           — campo reviewerUid adicionado")
print("  5. review_form_page.dart       — passa reviewerUid ao criar review")
print("  6. suggest_provider_page.dart  — Future com try/catch + feedback de erro")
print("  7. admin_panel_page.dart       — verificação de role + StatefulWidget")
print("                                   + try/catch nas categorias + (_, __)")
print("  8. providers_page.dart         — (_, _) → (_, __)")
print("  9. provider_detail_page.dart   — (_, _) → (_, __)")
print()
print("⚠️  Ação manual necessária no Firestore:")
print("  Crie a coleção 'meta' com o documento 'stats' contendo")
print("  { userCount: <número de usuários já cadastrados> }")
print("  para que a lógica de admin funcione corretamente.")
