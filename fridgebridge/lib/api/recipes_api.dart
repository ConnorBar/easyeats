import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe.dart';
import 'client.dart';
import 'inventory_api.dart';

// DYNAMIC FROM DB: Fetches all recipes from MongoDB with live-computed
// availability status injected by the backend. Watches inventoryProvider so
// availability auto-refreshes whenever the pantry changes.
final recipesProvider = FutureProvider.autoDispose<List<Recipe>>((ref) {
  ref.watch(inventoryProvider);
  return RecipesApi.getAll();
});

class RecipesApi {
  static Future<List<Recipe>> getAll() async {
    final response = await dio.get('/recipes');
    return (response.data as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Recipe> create(Map<String, dynamic> data) async {
    final response = await dio.post('/recipes', data: data);
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Recipe> update(String id, Map<String, dynamic> data) async {
    final response = await dio.put('/recipes/$id', data: data);
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await dio.delete('/recipes/$id');
  }

  static Future<Recipe> complete(String id) async {
    final response = await dio.post('/recipes/$id/complete');
    return Recipe.fromJson(response.data as Map<String, dynamic>);
  }
}
