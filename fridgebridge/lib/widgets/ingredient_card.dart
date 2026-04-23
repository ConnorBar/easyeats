import 'package:flutter/material.dart';

import '../models/inventory_item.dart';

class IngredientCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const IngredientCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expired = item.hasExpired;
    final expiringSoon = item.expiringSoon();

    final borderColor = expired
        ? Colors.red.withValues(alpha: 0.6)
        : expiringSoon
        ? Colors.orange.withValues(alpha: 0.6)
        : cs.outlineVariant.withValues(alpha: 0.3);

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: (expired || expiringSoon) ? 1.5 : 0.5,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Stack(
            children: [
              if (expired || expiringSoon)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (expired)
                        const Icon(Icons.error, size: 12, color: Colors.red),
                      if (expired && expiringSoon) const SizedBox(width: 2),
                      if (expiringSoon)
                        const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Colors.orange,
                        ),
                    ],
                  ),
                ),
              Center(
                // -------------------- ACTUAL CARD CONTENT -------------------- //
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _fmtQty(item.quantity),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.quantity > 0 ? cs.primary : Colors.grey,
                      ),
                    ),
                    Text(
                      item.unit,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}
