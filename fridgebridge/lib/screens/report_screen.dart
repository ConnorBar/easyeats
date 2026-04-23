import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/recipes_api.dart';
import '../api/report_api.dart';
import '../models/report.dart';
import '../widgets/report_filters.dart';
import '../widgets/report_stats_panel.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  Map<String, int> _portions = {};
  ShoppingListResponse? _result;
  bool _loading = false;
  String? _error;

  bool get _hasSelections => _portions.values.any((v) => v > 0);

  Future<void> _calculate() async {
    if (!_hasSelections) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ReportApi.getShoppingList(_portions);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // DYNAMIC FROM DB: Fetches all recipes from the database so the user
    // can select which ones to cook. Nothing hardcoded.
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meal Plan')),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (recipes) => ListView(
          children: [
            RecipeSelector(
              recipes: recipes,
              portions: _portions,
              onChanged: (v) => setState(() {
                _portions = v;
                _result = null;
              }),
            ),
            if (_hasSelections)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: FilledButton.icon(
                  onPressed: _loading ? null : _calculate,
                  icon: const Icon(Icons.calculate),
                  label: const Text('Calculate Shopping List'),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error: $_error',
                    style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text('Shopping List',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              ShoppingListPanel(data: _result!),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
