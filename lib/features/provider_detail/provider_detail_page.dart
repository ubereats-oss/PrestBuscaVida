import 'package:flutter/material.dart';
import '../../core/utils/phone_formatter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/provider_model.dart';
import '../../data/models/review_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/reviews_repository.dart';
import '../reviews/review_form_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderDetailPage extends StatefulWidget {
  final ProviderModel provider;
  const ProviderDetailPage({super.key, required this.provider});
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
      if (mounted) {
        final fbUser = FirebaseAuth.instance.currentUser;
        setState(
          () => _currentUser =
              user ??
              (fbUser == null
                  ? null
                  : UserModel(
                      uid: fbUser.uid,
                      email: fbUser.email,
                      phone: fbUser.phoneNumber,
                      displayName:
                          fbUser.displayName ?? fbUser.phoneNumber ?? 'Usuário',
                      role: 'user',
                      createdAt: DateTime.now(),
                    )),
        );
      }
    });
  }

  Future<void> _openWhatsApp() async {
    final number = widget.provider.whatsapp.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$number');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  Future<void> _makePhoneCall() async {
    final number = widget.provider.phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:$number');
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
        );
      }
    }
  }

  void _openReviewForm() {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde um momento e tente novamente.')),
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
      appBar: AppBar(title: Text(widget.provider.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.provider.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                'Telefone: ${formatPhone(widget.provider.phone)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 6),
            ],
            if (widget.provider.whatsapp.isNotEmpty) ...[
              Text(
                'WhatsApp: ${formatPhone(widget.provider.whatsapp)}',
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
                onPressed: _currentUser == null ? null : _openReviewForm,
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
              stream: _reviewsRepository.watchReviewsByProvider(
                widget.provider.id,
              ),
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
                  separatorBuilder: (_, _) => const Divider(height: 24),
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
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ratingColor(review.rating),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${review.rating}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
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

  Color _ratingColor(int rating) {
    if (rating <= 4) return Colors.red;
    if (rating <= 6) return Colors.orange;
    if (rating <= 8) return Colors.amber.shade700;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
