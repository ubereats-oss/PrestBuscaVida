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
                  'Erro ao carregar prestadores:\n${snapshot.error}',
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
            separatorBuilder: (_, _) => const Divider(height: 1),
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
                      ? '${provider.description}\n$ratingLine'
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
