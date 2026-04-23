import 'package:flutter/material.dart';
//import '../../core/utils/phone_formatter.dart';
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
  // modo: true = sugerir prestador | false = sugerir categoria
  bool _isProviderMode = true;
  // prestador
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descriptionController = TextEditingController();
  CategoryModel? _selectedCategory;
  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  String? _categoriesError;
  // categoria
  final _categoryNameController = TextEditingController();
  final _providersRepository = ProvidersRepository();
  final _categoriesRepository = CategoriesRepository();
  bool _isLoading = false;
  String? _errorMessage;
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
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoriesRepository.fetchActiveCategories();
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
              'Nao foi possivel carregar as categorias. Tente novamente.';
          _loadingCategories = false;
        });
      }
    }
  }

  Future<void> _submitProvider() async {
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
      if (mounted) _showSuccessDialog('Sugestao de prestador enviada!');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao enviar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitCategory() async {
    final name = _categoryNameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Informe o nome da categoria.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _categoriesRepository.suggestCategory(
        name: name,
        suggestedByUid: widget.currentUser.uid,
      );
      if (mounted) _showSuccessDialog('Sugestao de categoria enviada!');
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Erro ao enviar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: const Text(
          'Obrigado! Sua sugestao foi recebida e sera analisada pelo nosso time.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fazer uma sugestao')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Sugerir prestador'),
                  icon: Icon(Icons.person_add_outlined),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Sugerir categoria'),
                  icon: Icon(Icons.category_outlined),
                ),
              ],
              selected: {_isProviderMode},
              onSelectionChanged: (val) => setState(() {
                _isProviderMode = val.first;
                _errorMessage = null;
              }),
            ),
            const SizedBox(height: 24),
            if (_isProviderMode) ...[
              const Text(
                'Conhece um bom prestador de servico? Indique aqui!',
                style: TextStyle(fontSize: 16),
              ),
              const Text(
                'Sua sugestao sera revisada e, se aprovada, aparecera no app.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
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
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                            value: cat,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                    onChanged: (cat) => setState(() => _selectedCategory = cat),
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
                  labelText: 'WhatsApp (somente numeros com DDD)',
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
            ] else ...[
              const Text(
                'Nao encontrou a categoria que procura?',
                style: TextStyle(fontSize: 16),
              ),
              const Text(
                'Sugira uma nova categoria para ser avaliada pelo nosso time.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _categoryNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da categoria *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : (_isProviderMode ? _submitProvider : _submitCategory),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar sugestao'),
            ),
          ],
        ),
      ),
    );
  }
}
