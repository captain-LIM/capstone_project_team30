import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../models/recipe.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeName;
  final List<String> ingredients;

  const RecipeDetailScreen({
    super.key,
    required this.recipeName,
    required this.ingredients,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  RecipeDetail? _detail;
  bool _isLoading = true;
  bool _isSaved = false;
  bool _isSaving = false;

  final _api = ApiService();
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _load();
    _checkSaved();
  }

  Future<void> _load() async {
    try {
      final d = await _api.getRecipeDetail(widget.recipeName, widget.ingredients);
      if (mounted) setState(() { _detail = d; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로드 실패: $e')));
      }
    }
  }

  Future<void> _checkSaved() async {
    final saved = await _storage.getSavedRecipes();
    if (mounted) setState(() => _isSaved = saved.any((r) => r.name == widget.recipeName));
  }

  Future<void> _toggleSave() async {
    if (_detail == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_isSaved) {
        await _storage.deleteRecipe(_detail!.name);
      } else {
        await _storage.saveRecipe(_detail!);
      }
      setState(() { _isSaved = !_isSaved; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSaved ? '레시피가 저장되었습니다.' : '저장이 취소되었습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Text(widget.recipeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          if (_detail != null)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
              onPressed: _toggleSave,
              tooltip: _isSaved ? '저장 취소' : '레시피 저장',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('레시피를 불러올 수 없습니다.'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _detail!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            icon: Icons.shopping_basket_outlined,
            title: '재료',
            child: Column(
              children: d.ingredients.map((i) => _BulletItem(text: i)).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.format_list_numbered,
            title: '조리 방법',
            child: Column(
              children: d.steps.asMap().entries.map((e) => _StepItem(number: e.key + 1, text: e.value)).toList(),
            ),
          ),
          if (d.tips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2FAF6),
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
                  Text(d.tips, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ],
          if (d.youtubeLinks.isNotEmpty) ...[
            const SizedBox(height: 16),
            _YoutubeSection(links: d.youtubeLinks),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: kPrimary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      );
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 6, color: kPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
          ],
        ),
      );
}

class _StepItem extends StatelessWidget {
  final int number;
  final String text;
  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: Center(
                child: Text('$number',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(text, style: const TextStyle(height: 1.55)),
              ),
            ),
          ],
        ),
      );
}

// 유튜브 링크 섹션
class _YoutubeSection extends StatelessWidget {
  final List<YoutubeLink> links;
  const _YoutubeSection({required this.links});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('유튜브를 열 수 없습니다.')),
        );
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
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
          ...links.asMap().entries.map((e) => _YoutubeItem(
                index: e.key + 1,
                link: e.value,
                onTap: () => _open(context, e.value.url),
              )),
        ],
      ),
    );
  }
}

class _YoutubeItem extends StatelessWidget {
  final int index;
  final YoutubeLink link;
  final VoidCallback onTap;
  const _YoutubeItem({required this.index, required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            // 순위 뱃지
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: index == 1
                    ? const Color(0xFFFF0000)
                    : index == 2
                        ? const Color(0xFFFF5252)
                        : const Color(0xFFFF8A80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                link.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
