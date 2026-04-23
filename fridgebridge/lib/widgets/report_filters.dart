import 'package:flutter/material.dart';

import '../models/recipe.dart';

class RecipeSelector extends StatefulWidget {
  final List<Recipe> recipes;
  final Map<String, int> portions;
  final ValueChanged<Map<String, int>> onChanged;

  const RecipeSelector({
    super.key,
    required this.recipes,
    required this.portions,
    required this.onChanged,
  });

  @override
  State<RecipeSelector> createState() => _RecipeSelectorState();
}

class _RecipeSelectorState extends State<RecipeSelector> {
  TextEditingController? _searchCtrl;

  void _set(String id, int value) {
    final next = Map<String, int>.from(widget.portions);
    if (value <= 0) {
      next.remove(id);
    } else {
      next[id] = value;
    }
    widget.onChanged(next);
  }

  void _add(Recipe recipe) {
    if (widget.portions.containsKey(recipe.id)) return;
    _set(recipe.id, 1);
  }

  void _remove(String id) {
    final next = Map<String, int>.from(widget.portions)..remove(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.recipes
        .where((r) => widget.portions.containsKey(r.id))
        .toList();
    final unselected = widget.recipes
        .where((r) => !widget.portions.containsKey(r.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── search to add recipes ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text('Add Recipes',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          // DYNAMIC FROM DB: Autocomplete options come from the live
          // recipes list fetched via GET /recipes.
          child: Autocomplete<Recipe>(
            optionsBuilder: (textEditingValue) {
              if (textEditingValue.text.isEmpty) return const [];
              final lower = textEditingValue.text.toLowerCase();
              return unselected.where(
                  (r) => r.name.toLowerCase().contains(lower));
            },
            displayStringForOption: (r) => r.name,
            onSelected: (recipe) {
              _add(recipe);
              Future.microtask(() => _searchCtrl?.clear());
            },
            fieldViewBuilder:
                (context, controller, focusNode, onSubmitted) {
              _searchCtrl = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search recipes...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (_) {
                  controller.clear();
                },
              );
            },
          ),
        ),

        // ── selected recipes with portion steppers ──
        if (selected.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
            child: Text('Selected (${selected.length})',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          ...selected.map((r) {
            final count = widget.portions[r.id] ?? 1;
            return ListTile(
              dense: true,
              title: Text(r.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                '${r.ingredients.length} ingredients · $count portion${count > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11),
              ),
              leading: IconButton(
                icon: Icon(Icons.close,
                    size: 18,
                    color: Theme.of(context).colorScheme.error),
                onPressed: () => _remove(r.id),
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        size: 22),
                    onPressed: count > 1
                        ? () => _set(r.id, count - 1)
                        : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.add_circle_outline, size: 22),
                    onPressed: () => _set(r.id, count + 1),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
        ] else
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: Text('Search and add recipes above.',
                    style: TextStyle(color: Colors.grey))),
          ),
      ],
    );
  }
}
