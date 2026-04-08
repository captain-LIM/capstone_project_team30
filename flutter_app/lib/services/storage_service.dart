import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _savedKey = 'saved_recipes';
  static const _profileKey = 'user_profile';
  static const _ingredientsKey = 'ingredients';

  Future<List<RecipeDetail>> getSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => RecipeDetail.fromJson(e)).toList();
  }

  Future<void> saveRecipe(RecipeDetail recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedRecipes();
    if (!list.any((r) => r.name == recipe.name)) {
      list.insert(0, recipe);
      await prefs.setString(_savedKey, jsonEncode(list.map((r) => r.toJson()).toList()));
    }
  }

  Future<void> deleteRecipe(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getSavedRecipes();
    list.removeWhere((r) => r.name == name);
    await prefs.setString(_savedKey, jsonEncode(list.map((r) => r.toJson()).toList()));
  }

  Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<List<String>> getIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ingredientsKey);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw));
  }

  Future<void> saveIngredients(List<String> ingredients) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ingredientsKey, jsonEncode(ingredients));
  }
}
