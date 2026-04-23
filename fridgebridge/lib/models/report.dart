class ShoppingIngredient {
  final String name;
  final String unit;
  final double required;
  final double available;
  final double toBuy;

  ShoppingIngredient({
    required this.name,
    required this.unit,
    required this.required,
    required this.available,
    required this.toBuy,
  });

  factory ShoppingIngredient.fromJson(Map<String, dynamic> json) =>
      ShoppingIngredient(
        name: json['name'] ?? '',
        unit: json['unit'] ?? '',
        required: (json['required'] ?? 0).toDouble(),
        available: (json['available'] ?? 0).toDouble(),
        toBuy: (json['to_buy'] ?? 0).toDouble(),
      );
}

class SelectedRecipe {
  final String id;
  final String name;
  final int portions;

  SelectedRecipe({
    required this.id,
    required this.name,
    required this.portions,
  });

  factory SelectedRecipe.fromJson(Map<String, dynamic> json) =>
      SelectedRecipe(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        portions: json['portions'] ?? 1,
      );
}

class ShoppingListResponse {
  final List<SelectedRecipe> recipes;
  final List<ShoppingIngredient> ingredients;

  ShoppingListResponse({required this.recipes, required this.ingredients});

  factory ShoppingListResponse.fromJson(Map<String, dynamic> json) =>
      ShoppingListResponse(
        recipes: (json['recipes'] as List<dynamic>?)
                ?.map((e) =>
                    SelectedRecipe.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        ingredients: (json['ingredients'] as List<dynamic>?)
                ?.map((e) =>
                    ShoppingIngredient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
