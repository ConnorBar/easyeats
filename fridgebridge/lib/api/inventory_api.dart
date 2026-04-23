import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inventory_item.dart';
import 'client.dart';

// DYNAMIC FROM DB: This provider fetches the full inventory list from MongoDB
// via GET /inventory every time it is watched or invalidated. No hardcoded data.
final inventoryProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) {
  return InventoryApi.getAll();
});

class InventoryApi {
  static Future<List<InventoryItem>> getAll() async {
    final response = await dio.get('/inventory');
    return (response.data as List)
        .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<InventoryItem> create(Map<String, dynamic> data) async {
    final response = await dio.post('/inventory', data: data);
    return InventoryItem.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<InventoryItem> update(
      String id, Map<String, dynamic> data) async {
    final response = await dio.put('/inventory/$id', data: data);
    return InventoryItem.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<InventoryItem> addBatch(
      String id, double quantity, String? expireDate) async {
    final response = await dio.post('/inventory/$id/batch', data: {
      'quantity': quantity,
      if (expireDate != null) 'expireDate': expireDate,
    });
    return InventoryItem.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> delete(String id) async {
    await dio.delete('/inventory/$id');
  }
}
