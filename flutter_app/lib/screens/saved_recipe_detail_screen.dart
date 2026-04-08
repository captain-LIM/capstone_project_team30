import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/storage_service.dart';

class SavedRecipeDetailScreen extends StatelessWidget {
  final RecipeDetail recipe;

  const SavedRecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '삭제',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('레시피 삭제'),
                  content: Text('${recipe.name}\n레시피를 삭제하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await StorageService().deleteRecipe(recipe.name);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Card(
              icon: Icons.shopping_basket_outlined,
              title: '재료',
              child: Column(
                children: recipe.ingredients.map((i) => _Bullet(text: i)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              icon: Icons.format_list_numbered,
              title: '조리 방법',
              child: Column(
                children: recipe.steps.asMap().entries.map((e) => _Step(n: e.key + 1, text: e.value)).toList(),
              ),
            ),
            if (recipe.tips.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: kPrimary),
                        SizedBox(width: 8),
                        Text('요리 팁', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(recipe.tips, style: const TextStyle(height: 1.6)),
                  ],
                ),
              ),
            ],
            if (recipe.youtubeLinks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _YoutubeCard(links: recipe.youtubeLinks),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: kPrimary), const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
            const Divider(height: 20),
            child,
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: kPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
        ]),
      );
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            child: Center(child: Text('$n',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: const TextStyle(height: 1.55)),
          )),
        ]),
      );
}

class _YoutubeCard extends StatelessWidget {
  final List<YoutubeLink> links;
  const _YoutubeCard({required this.links});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('유튜브를 열 수 없습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.play_circle_outline, color: Color(0xFFFF0000)),
              SizedBox(width: 8),
              Text('관련 요리 영상', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              SizedBox(width: 6),
              Text('인기순', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const Divider(height: 20),
          ...links.asMap().entries.map((e) => InkWell(
                onTap: () => _open(context, e.value.url),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: e.key == 0
                              ? const Color(0xFFFF0000)
                              : e.key == 1
                                  ? const Color(0xFFFF5252)
                                  : const Color(0xFFFF8A80),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('${e.key + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(e.value.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                      const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
