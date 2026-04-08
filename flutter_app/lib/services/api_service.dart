import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';

class ApiService {
  static const _timeout = Duration(seconds: 60);

  Future<void> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$kBaseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) throw Exception('서버 응답 오류');
    } catch (_) {
      throw Exception('서버에 연결할 수 없습니다.\n서버가 실행 중인지 확인하세요.\n(URL: $kBaseUrl)');
    }
  }

  Future<List<String>> analyzeImage(File image) async {
    await checkConnection();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$kBaseUrl/api/analyze'),
    );
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['ingredients'] ?? []);
    }
    throw Exception(_errorMessage(response));
  }

  Future<List<Recipe>> getRecipes(
    List<String> ingredients,
    List<String> previousRecipes,
    UserProfile profile,
  ) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ingredients': ingredients,
            'previousRecipes': previousRecipes,
            'profile': profile.toJson(),
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['recipes'] as List).map((r) => Recipe.fromJson(r)).toList();
    }
    throw Exception(_errorMessage(response));
  }

  Future<RecipeDetail> getRecipeDetail(
    String recipeName,
    List<String> ingredients,
  ) async {
    final response = await http
        .post(
          Uri.parse('$kBaseUrl/api/recipe-detail'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipeName': recipeName,
            'ingredients': ingredients,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return RecipeDetail.fromJson(jsonDecode(response.body));
    }
    throw Exception(_errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] ?? '서버 오류 (${response.statusCode})';
    } catch (_) {
      return '서버 오류 (${response.statusCode})';
    }
  }
}
