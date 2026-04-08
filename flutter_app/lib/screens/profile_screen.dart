import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  UserProfile _profile = UserProfile();
  bool _isLoading = true;
  bool _isSaving = false;

  final _storage = StorageService();

  static const _allergies = ['견과류', '유제품', '해산물', '밀', '계란', '대두'];
  static const _dietary = ['없음', '채식', '비건', '할랄'];
  static const _cuisines = ['한식', '중식', '양식', '일식'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await _storage.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _nicknameCtrl.text = p.nickname;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    _profile.nickname = _nicknameCtrl.text.trim();
    await _storage.saveProfile(_profile);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('내 프로필', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 닉네임
                  _ProfileCard(
                    title: '닉네임',
                    child: TextField(
                      controller: _nicknameCtrl,
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력하세요',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 알레르기
                  _ProfileCard(
                    title: '알레르기',
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: _allergies.map((a) {
                        final selected = _profile.allergies.contains(a);
                        return FilterChip(
                          label: Text(a),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            v ? _profile.allergies.add(a) : _profile.allergies.remove(a);
                          }),
                          selectedColor: kPrimary.withOpacity(0.15),
                          checkmarkColor: kPrimary,
                          labelStyle: TextStyle(color: selected ? kPrimary : null),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 식이 제한
                  _ProfileCard(
                    title: '식이 제한',
                    child: Column(
                      children: _dietary.map((d) => RadioListTile<String>(
                        title: Text(d),
                        value: d,
                        groupValue: _profile.dietaryRestriction,
                        onChanged: (v) => setState(() => _profile.dietaryRestriction = v!),
                        activeColor: kPrimary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 선호 요리
                  _ProfileCard(
                    title: '선호 요리 종류',
                    child: Wrap(
                      spacing: 8, runSpacing: 6,
                      children: _cuisines.map((c) {
                        final selected = _profile.preferredCuisines.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            v ? _profile.preferredCuisines.add(c) : _profile.preferredCuisines.remove(c);
                          }),
                          selectedColor: kPrimary.withOpacity(0.15),
                          checkmarkColor: kPrimary,
                          labelStyle: TextStyle(color: selected ? kPrimary : null),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProfileCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}
