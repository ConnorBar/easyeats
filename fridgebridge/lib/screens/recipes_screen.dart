import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/recipes_api.dart';
import '../models/recipe.dart';
import '../widgets/add_edit_recipe_sheet.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'available', label: Text('Can Make')),
                ButtonSegment(value: 'partial', label: Text('Almost')),
                ButtonSegment(value: 'unavailable', label: Text("Can't")),
              ],
              selected: {_filter},
              onSelectionChanged: (s) =>
                  setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: recipesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (recipes) {
                final filtered = _filter == 'all'
                    ? recipes
                    : recipes
                        .where((r) => r.availability == _filter)
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No recipes in this category.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => RecipeCard(
                    recipe: filtered[i],
                    onTap: () => _openDetail(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipe_fab',
        onPressed: _addRecipe,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipe: recipe)),
    );
  }

  void _addRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditRecipeSheet()),
    );
  }
}
