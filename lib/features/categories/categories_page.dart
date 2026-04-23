import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/category_model.dart';
import '../../data/repositories/categories_repository.dart';
import '../providers/providers_page.dart';
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}
class _CategoriesPageState extends State<CategoriesPage> {
  final _repository = CategoriesRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<List<CategoryModel>> _future;
  List<CategoryModel> _all = [];
  List<CategoryModel> _filtered = [];
  String? _activeLetter;
  List<String> _letters = [];
  final Map<String, GlobalKey> _sectionKeys = {};
  @override
  void initState() {
    super.initState();
    _future = _repository.fetchActiveCategories();
    _future.then((list) {
      _all = list;
      _applyFilter('');
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _applyFilter(String query) {
    final q = query.trim().toLowerCase();
    final result = q.isEmpty
        ? List<CategoryModel>.of(_all)
        : _all.where((c) => c.name.toLowerCase().contains(q)).toList();
    _sectionKeys.clear();
    final lettersSet = <String>{};
    for (final c in result) {
      if (c.name.isEmpty) continue;
      lettersSet.add(c.name[0].toUpperCase());
    }
    final letters = lettersSet.toList()..sort();
    for (final l in letters) {
      _sectionKeys[l] = GlobalKey();
    }
    setState(() {
      _filtered = result;
      _letters = letters;
      _activeLetter = null;
    });
  }
  void _scrollToLetter(String letter) {
    final ctx = _sectionKeys[letter]?.currentContext;
    if (ctx == null) return;
    HapticFeedback.selectionClick();
    setState(() => _activeLetter = letter);
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.0,
    );
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias de serviços'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _applyFilter,
              decoration: InputDecoration(
                hintText: 'Buscar categoria…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilter('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<CategoryModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Erro ao carregar categorias:\n\${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_filtered.isEmpty) {
            return const Center(
              child: Text('Nenhuma categoria encontrada.'),
            );
          }
          // agrupa por letra
          final Map<String, List<CategoryModel>> grouped = {};
          for (final c in _filtered) {
            if (c.name.isEmpty) continue;
            grouped.putIfAbsent(c.name[0].toUpperCase(), () => []).add(c);
          }
          return Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(right: 32),
                itemCount: _letters.length,
                itemBuilder: (_, i) {
                  final letter = _letters[i];
                  final items = grouped[letter] ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        key: _sectionKeys.putIfAbsent(letter, () => GlobalKey()),
                        width: double.infinity,
                        color: colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ...items.map(
                        (category) => ListTile(
                          title: Text(category.name),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProvidersPage(
                                categoryId: category.id,
                                categoryName: category.name,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_searchController.text.isEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _AlphabetIndex(
                    letters: _letters,
                    activeLetter: _activeLetter,
                    onLetterTap: _scrollToLetter,
                    colorScheme: colorScheme,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
class _AlphabetIndex extends StatelessWidget {
  final List<String> letters;
  final String? activeLetter;
  final ValueChanged<String> onLetterTap;
  final ColorScheme colorScheme;
  const _AlphabetIndex({
    required this.letters,
    required this.activeLetter,
    required this.onLetterTap,
    required this.colorScheme,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localY = box.globalToLocal(details.globalPosition).dy;
        final itemHeight = box.size.height / letters.length;
        final idx = (localY / itemHeight).floor().clamp(0, letters.length - 1);
        onLetterTap(letters[idx]);
      },
      child: Container(
        width: 28,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters.map((l) {
            final isActive = l == activeLetter;
            return GestureDetector(
              onTap: () => onLetterTap(l),
              child: Container(
                width: 28,
                height: 22,
                alignment: Alignment.center,
                decoration: isActive
                    ? BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
