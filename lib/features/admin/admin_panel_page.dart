//import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import '../../core/utils/phone_formatter.dart';
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
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final provider = pending[index];
            return ListTile(
              title: Text(provider.name),
              subtitle: Text(
                '${provider.categoryName.isNotEmpty ? provider.categoryName : provider.categoryId}'
                '${provider.description.isNotEmpty ? '\n${provider.description}' : ''}',
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
  final _indicacaoController = TextEditingController();
  final _observacaoController = TextEditingController();
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
    _indicacaoController.dispose();
    _observacaoController.dispose();
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
        indicacao: _indicacaoController.text.trim(),
        observacao: _observacaoController.text.trim(),
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
        _indicacaoController.clear();
        _observacaoController.clear();
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
            onChanged: (v) {
              final formatted = formatPhoneInput(v);
              if (formatted != v) {
                _phoneController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _whatsappController,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (v) {
              final formatted = formatPhoneInput(v);
              if (formatted != v) {
                _whatsappController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            },
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
          const SizedBox(height: 16),
          TextField(
            controller: _indicacaoController,
            decoration: const InputDecoration(
              labelText: 'Indicação (quem indicou)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observacaoController,
            decoration: const InputDecoration(
              labelText: 'Observação interna',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
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
