import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/inventory_api.dart';
import '../api/recipes_api.dart';
import '../models/inventory_item.dart';
import '../models/recipe.dart';

class _IngredientRowData {
  String? ingredientId;
  String name;
  final TextEditingController qtyController;
  final TextEditingController unitController;

  _IngredientRowData({
    this.ingredientId,
    this.name = '',
    String? qty,
    String? unit,
  })  : qtyController = TextEditingController(text: qty ?? ''),
        unitController = TextEditingController(text: unit ?? '');

  void dispose() {
    qtyController.dispose();
    unitController.dispose();
  }
}

// DYNAMIC FROM DB: This widget calls GET /inventory (via inventoryProvider)
// and uses the response to build the ingredient selector rows dynamically.
// The ingredient dropdown list is never hardcoded — it always reflects the
// live state of the inventory collection in MongoDB.
class AddEditRecipeSheet extends ConsumerStatefulWidget {
  final Recipe? recipe;

  const AddEditRecipeSheet({super.key, this.recipe});

  @override
  ConsumerState<AddEditRecipeSheet> createState() =>
      _AddEditRecipeSheetState();
}

class _AddEditRecipeSheetState extends ConsumerState<AddEditRecipeSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<_IngredientRowData> _rows = [];
  List<InventoryItem> _inventory = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    if (r != null) {
      _nameCtrl.text = r.name;
      _descCtrl.text = r.description;
      for (final ing in r.ingredients) {
        _rows.add(_IngredientRowData(
          ingredientId: ing.ingredientId,
          name: ing.name,
          qty: _fmtQty(ing.quantity),
          unit: ing.unit,
        ));
      }
    }
    if (_rows.isEmpty) _addRow();
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  void _addRow() => setState(() => _rows.add(_IngredientRowData()));

  void _removeRow(int i) {
    _rows[i].dispose();
    setState(() => _rows.removeAt(i));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Recipe name is required')));
      return;
    }

    // Resolve or create inventory items for every ingredient row.
    // If the ingredient exists in inventory, link by ID.
    // If it doesn't exist, create it with quantity 0 so the availability
    // logic correctly flags it as missing.
    final validRows = _rows.where((r) => r.name.trim().isNotEmpty).toList();

    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Add at least one ingredient')));
      return;
    }

    setState(() => _saving = true);

    for (final r in validRows) {
      if (r.ingredientId == null) {
        final match = _inventory
            .where((item) =>
                item.name.toLowerCase() == r.name.trim().toLowerCase())
            .toList();
        if (match.isNotEmpty) {
          r.ingredientId = match.first.id;
          r.name = match.first.name;
        } else {
          final unit = r.unitController.text.trim().isNotEmpty
              ? r.unitController.text.trim()
              : 'whole';
          final created = await InventoryApi.create({
            'name': r.name.trim(),
            'quantity': 0,
            'unit': unit,
          });
          r.ingredientId = created.id;
          r.name = created.name;
        }
      }
    }

    final ingredients = validRows
        .map((r) => <String, dynamic>{
              'ingredientId': r.ingredientId,
              'name': r.name,
              'quantity': double.tryParse(r.qtyController.text) ?? 0,
              'unit': r.unitController.text,
            })
        .toList();

    final data = <String, dynamic>{
      'name': name,
      'description': desc,
      'ingredients': ingredients,
    };

    if (widget.recipe != null) {
      await RecipesApi.update(widget.recipe!.id, data);
    } else {
      await RecipesApi.create(data);
    }
    ref.invalidate(recipesProvider);
    ref.invalidate(inventoryProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // DYNAMIC FROM DB: inventoryProvider triggers GET /inventory and the
    // result populates every ingredient Autocomplete dropdown.
    final inventoryAsync = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.recipe == null ? 'Add Recipe' : 'Edit Recipe'),
      ),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading inventory: $e')),
        data: (inventory) {
          _inventory = inventory;
          return _buildForm(inventory);
        },
      ),
    );
  }

  Widget _buildForm(List<InventoryItem> inventory) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
              labelText: 'Recipe Name', border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
              labelText: 'Description', border: OutlineInputBorder()),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 20),
        Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(
            _rows.length, (i) => _buildIngredientRow(i, inventory)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Ingredient'),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.recipe == null ? 'Create Recipe' : 'Save Changes'),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(int index, List<InventoryItem> inventory) {
    final row = _rows[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DYNAMIC FROM DB: Autocomplete options come from the live
            // inventory list fetched via GET /inventory.
            Expanded(
              flex: 3,
              child: Autocomplete<InventoryItem>(
                initialValue: TextEditingValue(text: row.name),
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return inventory;
                  final lower = textEditingValue.text.toLowerCase();
                  return inventory.where(
                      (item) => item.name.toLowerCase().contains(lower));
                },
                displayStringForOption: (item) => item.name,
                onSelected: (item) {
                  row.ingredientId = item.id;
                  row.name = item.name;
                  row.unitController.text = item.unit;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                        labelText: 'Ingredient',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onChanged: (v) {
                      row.name = v;
                      row.ingredientId = null;
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: row.qtyController,
                decoration: const InputDecoration(
                    labelText: 'Qty',
                    border: OutlineInputBorder(),
                    isDense: true),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: row.unitController,
                decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    isDense: true),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: () => _removeRow(index),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
