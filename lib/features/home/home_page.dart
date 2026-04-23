import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../admin/admin_panel_page.dart';
import '../categories/categories_page.dart';
import '../providers/providers_page.dart';
import '../suggestions/suggest_provider_page.dart';
import '../profile/profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _authRepository = AuthRepository();
  UserModel? _currentUser;
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authRepository.getCurrentUserModel();
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
  }

  void _openSearchResult() {
    final query = _searchController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProvidersPage(
          categoryName: query.isEmpty ? 'Todos os prestadores' : 'Busca',
          searchQuery: query,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja encerrar sua sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _authRepository.signOut();
      // O StreamBuilder em app.dart redireciona para AuthPage automaticamente.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca Vida Serviços'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentUser != null) ...[
              Text(
                'Olá, ${_currentUser!.displayName}!',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
            ],
            const Text(
              'Encontre prestadores de serviço confiáveis',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou serviço',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _openSearchResult(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _openSearchResult,
              child: const Text('Buscar prestadores'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                );
              },
              child: const Text('Ver categorias de serviços'),
            ),
            const SizedBox(height: 12),
            if (_currentUser != null) ...[
              if (_currentUser!.isAdmin)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminPanelPage()),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Painel de administração'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SuggestProviderPage(currentUser: _currentUser!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_business),
                  label: const Text('Fazer uma sugestao'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
