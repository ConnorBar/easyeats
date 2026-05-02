import '../models/report.dart';
import 'client.dart';

class ReportApi {
  static Future<ShoppingListResponse> getShoppingList(
    Map<String, int> recipePortions,
  ) async {
    final items = recipePortions.entries
        .where((e) => e.value > 0)
        .map((e) => {'recipe_id': e.key, 'portions': e.value})
        .toList();
    final response = await dio.post(
      '/report/shopping-list',
      data: {'items': items},
    );
    return ShoppingListResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
