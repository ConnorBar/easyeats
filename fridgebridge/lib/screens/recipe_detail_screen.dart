import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/inventory_api.dart';
import '../api/recipes_api.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';
import '../widgets/add_edit_recipe_sheet.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live list so this screen rebuilds automatically after an edit.
    final recipesAsync = ref.watch(recipesProvider);
    final inventoryAsync = ref.watch(inventoryProvider);

    if (!recipesAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Look up the latest version of this recipe by ID.
    final recipe = recipesAsync.value!
        .where((r) => r.id == recipeId)
        .firstOrNull;

    // Recipe was deleted elsewhere — just close.
    if (recipe == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final invMap = <String, InventoryItem>{};
    if (inventoryAsync.hasValue) {
      for (final item in inventoryAsync.value!) {
        invMap[item.id] = item;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddEditRecipeSheet(recipe: recipe)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context, ref, recipe),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── availability badge ──
          _availabilityBanner(context, recipe),
          const SizedBox(height: 12),
          Text(recipe.description,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Text('Ingredients',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...recipe.ingredients.map((ing) {
            final missing = recipe.missingIngredients
                .where((m) => m.name == ing.name)
                .toList();
            final color = missing.isEmpty
                ? Colors.green
                : missing.first.available == 0
                    ? Colors.red
                    : Colors.orange;
            final invItem = invMap[ing.ingredientId];
            final expired = invItem != null && invItem.hasExpired;
            final expiringSoon = invItem != null && invItem.expiringSoon();

            return ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: color, size: 14),
                  if (expired) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.error, size: 14, color: Colors.red),
                  ],
                  if (expiringSoon) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.schedule, size: 14, color: Colors.orange),
                  ],
                ],
              ),
              title: Text(ing.name),
              trailing: Text(
                  '${_fmtQty(ing.quantity)} ${ing.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: missing.isNotEmpty
                  ? Text(
                      missing.first.available == 0
                          ? 'Not in stock'
                          : 'Have ${_fmtQty(missing.first.available)} / need ${_fmtQty(missing.first.requiredQty)}',
                      style: TextStyle(color: color, fontSize: 12))
                  : null,
              visualDensity: VisualDensity.compact,
            );
          }),
          const SizedBox(height: 32),
          _completeButton(context, ref, recipe),
        ],
      ),
    );
  }

  Widget _availabilityBanner(BuildContext context, Recipe recipe) {
    Color bg;
    String label;
    switch (recipe.availability) {
      case 'available':
        bg = Colors.green;
        label = 'You have everything!';
        break;
      case 'partial':
        bg = Colors.orange;
        label = 'Almost — missing a few items';
        break;
      default:
        bg = Colors.red;
        label = 'Cannot make — missing ingredients';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.info_outline, color: bg, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(color: bg, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _completeButton(BuildContext context, WidgetRef ref, Recipe recipe) {
    final enabled = recipe.availability != 'unavailable';
    return FilledButton.icon(
      onPressed: enabled
          ? () => _handleComplete(context, ref, recipe)
          : null,
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Mark Complete'),
    );
  }

  Future<void> _handleComplete(BuildContext context, WidgetRef ref, Recipe recipe) async {
    if (recipe.availability == 'partial') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Missing ingredients'),
          content: Text(
              'You are short on ${recipe.missingIngredients.length} ingredient(s). Continue anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cook anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }

    await RecipesApi.complete(recipe.id);
    ref.invalidate(recipesProvider);
    ref.invalidate(inventoryProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recipe completed! Ingredients deducted.')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove "${recipe.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await RecipesApi.delete(recipe.id);
    ref.invalidate(recipesProvider);
    if (context.mounted) Navigator.pop(context);
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
