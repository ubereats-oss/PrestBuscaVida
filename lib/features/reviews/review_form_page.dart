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
  int _rating = 5;
  bool _isLoading = false;
  String? _errorMessage;
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  Future<void> _submit() async {
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
          const SnackBar(content: Text('Avaliacao enviada. Obrigado!')),
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
  String _ratingLabel(int rating) {
    if (rating <= 2) return 'Pessimo';
    if (rating <= 4) return 'Ruim';
    if (rating <= 6) return 'Regular';
    if (rating <= 8) return 'Bom';
    if (rating == 9) return 'Muito bom';
    return 'Excelente';
  }
  Color _ratingColor(int rating) {
    if (rating <= 4) return Colors.red;
    if (rating <= 6) return Colors.orange;
    if (rating <= 8) return Colors.amber.shade700;
    return Colors.green;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar prestador')),
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
            const SizedBox(height: 28),
            const Text(
              'Sua nota',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _rating > 1
                      ? () => setState(() => _rating--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 36),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ratingColor(_rating),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_rating',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _rating < 10
                      ? () => setState(() => _rating++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline, size: 36),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _ratingLabel(_rating),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _ratingColor(_rating),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'escala de 1 a 10',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
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
                  : const Text('Enviar avaliacao'),
            ),
          ],
        ),
      ),
    );
  }
}
