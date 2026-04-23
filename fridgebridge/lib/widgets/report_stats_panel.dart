import 'package:flutter/material.dart';

import '../models/report.dart';

class ShoppingListPanel extends StatelessWidget {
  final ShoppingListResponse data;

  const ShoppingListPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final toBuy = data.ingredients.where((i) => i.toBuy > 0).toList();
    final inStock = data.ingredients.where((i) => i.toBuy == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── To Buy section ──
        _SectionHeader(
          icon: Icons.shopping_cart,
          label: 'To Buy (${toBuy.length})',
          color: Colors.red.shade700,
        ),
        if (toBuy.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              'You have everything you need!',
              style: TextStyle(color: Colors.green),
            ),
          )
        else
          _IngredientTable(
            items: toBuy,
            columns: const ['Ingredient', 'Need', 'Have', 'Buy'],
            showBuy: true,
          ),

        const SizedBox(height: 12),

        // ── In Stock section ──
        if (inStock.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.check_circle_outline,
            label: 'Already Have (${inStock.length})',
            color: Colors.green.shade700,
          ),
          _IngredientTable(
            items: inStock,
            columns: const ['Ingredient', 'Need', 'Have', 'Remaining'],
            showBuy: false,
            muted: true,
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _IngredientTable extends StatelessWidget {
  final List<ShoppingIngredient> items;
  final List<String> columns;
  final bool showBuy;
  final bool muted;

  const _IngredientTable({
    required this.items,
    required this.columns,
    required this.showBuy,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final widths = showBuy
        ? const <int, TableColumnWidth>{
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          }
        : const <int, TableColumnWidth>{
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Table(
        columnWidths: widths,
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            children: columns.map((c) => _HeaderCell(c)).toList(),
          ),
          ...items.map((ing) {
            final textColor = muted ? Colors.grey.shade600 : null;
            final cells = <Widget>[
              _Cell(ing.name, color: textColor),
              _Cell('${_fmt(ing.required)} ${ing.unit}', color: textColor),
              _Cell('${_fmt(ing.available)} ${ing.unit}', color: textColor),
            ];
            if (showBuy) {
              // To Buy quantity
              cells.add(
                _Cell(
                  '${_fmt(ing.toBuy)} ${ing.unit}',
                  color: Colors.red.shade700,
                  bold: true,
                ),
              );
            } else {
              // Remaining quantity
              cells.add(
                _Cell(
                  '${_fmt(ing.available - ing.required)} ${ing.unit}',
                  color: textColor,
                ),
              );
            }
            return TableRow(children: cells);
          }),
        ],
      ),
    );
  }

  String _fmt(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _Cell extends StatelessWidget {
  final String text;
  final Color? color;
  final bool bold;

  const _Cell(this.text, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: bold ? FontWeight.w700 : null,
      ),
    ),
  );
}
