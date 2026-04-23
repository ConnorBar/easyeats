import 'package:flutter/material.dart';

import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  Color _badgeColor() {
    switch (recipe.availability) {
      case 'available':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _badgeLabel() {
    switch (recipe.availability) {
      case 'available':
        return 'Can Make';
      case 'partial':
        return 'Almost';
      default:
        return "Can't Make";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(recipe.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _badgeColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_badgeLabel(),
                        style: TextStyle(
                            color: _badgeColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(recipe.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text('${recipe.ingredients.length} ingredients',
                  style: Theme.of(context).textTheme.labelSmall),
              if (recipe.missingIngredients.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: recipe.missingIngredients
                      .map((m) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(m.name,
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
