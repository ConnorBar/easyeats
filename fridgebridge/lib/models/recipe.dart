class RecipeIngredient {
  final String ingredientId;
  final String name;
  final double quantity;
  final String unit;

  RecipeIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        ingredientId: json['ingredientId'] ?? '',
        name: json['name'] ?? '',
        quantity: (json['quantity'] ?? 0).toDouble(),
        unit: json['unit'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ingredientId': ingredientId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
      };
}

class MissingIngredient {
  final String name;
  final double requiredQty;
  final double available;
  final String unit;

  MissingIngredient({
    required this.name,
    required this.requiredQty,
    required this.available,
    required this.unit,
  });

  factory MissingIngredient.fromJson(Map<String, dynamic> json) =>
      MissingIngredient(
        name: json['name'] ?? '',
        requiredQty: (json['required'] ?? 0).toDouble(),
        available: (json['available'] ?? 0).toDouble(),
        unit: json['unit'] ?? '',
      );
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final List<RecipeIngredient> ingredients;
  final String availability;
  final List<MissingIngredient> missingIngredients;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.ingredients,
    this.availability = 'unavailable',
    this.missingIngredients = const [],
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) =>
                    RecipeIngredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        availability: json['availability'] ?? 'unavailable',
        missingIngredients: (json['missing_ingredients'] as List<dynamic>?)
                ?.map((e) =>
                    MissingIngredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
