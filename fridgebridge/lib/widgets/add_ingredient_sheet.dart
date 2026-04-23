import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../api/inventory_api.dart';
import '../models/inventory_item.dart';

const _units = ['whole', 'g', 'kg', 'oz', 'lbs'];

// ── Helper for batch rows in edit mode ──

class _BatchRowData {
  final TextEditingController qtyCtrl;
  DateTime? expireDate;

  _BatchRowData({double? qty, this.expireDate})
      : qtyCtrl = TextEditingController(
            text: qty != null
                ? (qty == qty.roundToDouble()
                    ? qty.toInt().toString()
                    : qty.toStringAsFixed(2))
                : '');

  void dispose() => qtyCtrl.dispose();
}

// ── Sheet widget ──

class AddIngredientSheet extends ConsumerStatefulWidget {
  final InventoryItem? item;

  const AddIngredientSheet({super.key, this.item});

  @override
  ConsumerState<AddIngredientSheet> createState() =>
      _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<AddIngredientSheet> {
  // Shared fields
  String _unit = 'whole';
  bool _saving = false;

  // Add-mode fields
  final _qtyCtrl = TextEditingController();
  DateTime? _expireDate;
  InventoryItem? _matchedItem;
  String _typedName = '';

  // Edit-mode fields
  final _nameCtrl = TextEditingController();
  final List<_BatchRowData> _batchRows = [];
  final _storeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _matchedItem = it;
      _typedName = it.name;
      _nameCtrl.text = it.name;
      _unit = _units.contains(it.unit) ? it.unit : 'whole';
      for (final b in it.batches) {
        _batchRows.add(_BatchRowData(
          qty: b.quantity,
          expireDate:
              b.expireDate != null ? DateTime.tryParse(b.expireDate!) : null,
        ));
      }
      if (_batchRows.isEmpty) {
        _batchRows.add(_BatchRowData(qty: it.quantity));
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _nameCtrl.dispose();
    _storeCtrl.dispose();
    _priceCtrl.dispose();
    for (final r in _batchRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({DateTime? initial, ValueChanged<DateTime>? onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null && onPicked != null) onPicked(picked);
  }

  // ── Save logic ──

  Future<void> _save() async {
    setState(() => _saving = true);

    if (_isEdit) {
      await _saveEdit();
    } else {
      await _saveAdd();
    }

    ref.invalidate(inventoryProvider);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveAdd() async {
    final name = _typedName.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (name.isEmpty || qty == null || qty <= 0) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('Name and valid quantity are required')));
      return;
    }

    final expStr = _expireDate?.toIso8601String().split('T').first;

    if (_matchedItem != null) {
      final List<Map<String, dynamic>> history =
          _matchedItem!.priceHistory.map((e) => e.toJson()).toList();
      if (_storeCtrl.text.trim().isNotEmpty &&
          _priceCtrl.text.trim().isNotEmpty) {
        history.add({
          'store': _storeCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
        await InventoryApi.update(_matchedItem!.id, {'priceHistory': history});
      }
      await InventoryApi.addBatch(_matchedItem!.id, qty, expStr);
    } else {
      final data = <String, dynamic>{
        'name': name,
        'quantity': qty,
        'unit': _unit,
        if (expStr != null) 'expireDate': expStr,
      };
      if (_storeCtrl.text.trim().isNotEmpty &&
          _priceCtrl.text.trim().isNotEmpty) {
        data['priceHistory'] = [
          {
            'store': _storeCtrl.text.trim(),
            'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          }
        ];
      }
      await InventoryApi.create(data);
    }
  }

  Future<void> _saveEdit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Name is required')));
      return;
    }

    final batches = _batchRows
        .map((r) => {
              'quantity': double.tryParse(r.qtyCtrl.text) ?? 0,
              'expireDate':
                  r.expireDate?.toIso8601String().split('T').first,
            })
        .where((b) => (b['quantity'] as double?) != null && (b['quantity'] as double) > 0)
        .toList();

    final data = <String, dynamic>{
      'name': name,
      'unit': _unit,
      'batches': batches,
    };

    final List<Map<String, dynamic>> history =
        widget.item!.priceHistory.map((e) => e.toJson()).toList();
    if (_storeCtrl.text.trim().isNotEmpty &&
        _priceCtrl.text.trim().isNotEmpty) {
      history.add({
        'store': _storeCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
    }
    data['priceHistory'] = history;

    await InventoryApi.update(widget.item!.id, data);
  }

  // ── Batches Display (edit mode) ──

  bool _batchesExpanded = false;

  int _soonestBatchIndex() {
    int best = 0;
    DateTime? bestDate;
    for (int i = 0; i < _batchRows.length; i++) {
      final d = _batchRows[i].expireDate;
      if (d != null && (bestDate == null || d.isBefore(bestDate))) {
        best = i;
        bestDate = d;
      }
    }
    return best;
  }

  List<Widget> _buildBatchesSection() {
    if (_batchRows.isEmpty) return [];

    final soonestIdx = _soonestBatchIndex();
    final hasMore = _batchRows.length > 1;

    return [
      Text('Batches', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      _buildBatchRow(soonestIdx, label: 'Soonest expiring'),
      if (hasMore) ...[
        InkWell(
          onTap: () => setState(() => _batchesExpanded = !_batchesExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_batchRows.length - 1} more batch${_batchRows.length - 1 > 1 ? 'es' : ''}',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Icon(
                  _batchesExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_batchesExpanded)
          ...List.generate(_batchRows.length, (i) => i)
              .where((i) => i != soonestIdx)
              .map((i) => _buildBatchRow(i)),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () =>
              setState(() => _batchRows.add(_BatchRowData())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add batch'),
        ),
      ),
    ];
  }

  // ── Price History Display ──

  bool _historyExpanded = false;

  Widget _buildPriceSummary(List<PriceEntry> history) {
    final prices = history.map((e) => e.price).toList();
    final avg = prices.reduce((a, b) => a + b) / prices.length;
    final best = prices.reduce((a, b) => a < b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _PriceStat(
              label: 'Best Price',
              value: '\$${best.toStringAsFixed(2)}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PriceStat(
              label: 'Avg Price',
              value: '\$${avg.toStringAsFixed(2)}'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PriceStat(
              label: 'Entries',
              value: '${history.length}'),
        ),
      ],
    );
  }

  Widget _buildPriceHistoryList(List<PriceEntry> history) {
    final sorted = List<PriceEntry>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('Price History',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Icon(
                  _historyExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_historyExpanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = sorted[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.store,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        '\$${e.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        e.date,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit Ingredient' : 'Add Ingredient',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            // ── Name field ──
            if (_isEdit)
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
              )
            else
              inventoryAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextField(
                  decoration: const InputDecoration(
                      labelText: 'Name', border: OutlineInputBorder()),
                  onChanged: (v) {
                    _typedName = v;
                    _matchedItem = null;
                  },
                ),
                data: (inventory) => Autocomplete<InventoryItem>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return inventory;
                    final lower = textEditingValue.text.toLowerCase();
                    return inventory.where(
                        (i) => i.name.toLowerCase().contains(lower));
                  },
                  displayStringForOption: (i) => i.name,
                  onSelected: (item) {
                    _matchedItem = item;
                    _typedName = item.name;
                    _unit =
                        _units.contains(item.unit) ? item.unit : 'whole';
                    setState(() {});
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: _matchedItem != null
                            ? const Icon(Icons.link,
                                color: Colors.green, size: 20)
                            : null,
                      ),
                      onChanged: (v) {
                        _typedName = v;
                        if (_matchedItem != null &&
                            _matchedItem!.name.toLowerCase() !=
                                v.trim().toLowerCase()) {
                          _matchedItem = null;
                          setState(() {});
                        }
                      },
                    );
                  },
                ),
              ),

            if (_matchedItem != null && !_isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Will add batch to "${_matchedItem!.name}" '
                  '(${_fmtQty(_matchedItem!.quantity)} ${_matchedItem!.unit} total)',
                  style:
                      TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
              ),

            const SizedBox(height: 12),

            // ── Unit selector (shared) ──
            if (!_isEdit) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder()),
                      items: _units
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _unit = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickDate(
                  initial: _expireDate,
                  onPicked: (d) => setState(() => _expireDate = d),
                ),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_expireDate != null
                    ? 'Expires: ${DateFormat.yMMMd().format(_expireDate!)}'
                    : 'Set expiration date (optional)'),
              ),
            ],

            // ── Edit mode: unit + batches ──
            if (_isEdit) ...[
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(
                    labelText: 'Unit', border: OutlineInputBorder()),
                items: _units
                    .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _unit = v);
                },
              ),
              const SizedBox(height: 16),
              ..._buildBatchesSection(),
              // ── Price history display (edit mode) ──
              if (widget.item!.priceHistory.isNotEmpty) ...[
                const Divider(height: 20),
                _buildPriceSummary(widget.item!.priceHistory),
                const SizedBox(height: 8),
                _buildPriceHistoryList(widget.item!.priceHistory),
              ],
              const Divider(height: 20),
              Text('Add Price Entry (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Store',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
            ],

            // ── Price entry fields (add mode) ──
            if (!_isEdit) ...[
              const Divider(height: 20),
              Text('Add Price Entry (optional)',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _storeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Store',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Price',
                          border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit
                      ? 'Save Changes'
                      : _matchedItem != null
                          ? 'Add to ${_matchedItem!.name}'
                          : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchRow(int index, {String? label}) {
    final row = _batchRows[index];
    final expired = row.expireDate != null &&
        row.expireDate!.isBefore(DateTime.now());
    final soon = !expired &&
        row.expireDate != null &&
        row.expireDate!
            .isBefore(DateTime.now().add(const Duration(days: 3)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
          Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.qtyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: expired
                        ? Colors.red
                        : soon
                            ? Colors.orange
                            : Colors.grey.shade400),
              ),
              onPressed: () => _pickDate(
                initial: row.expireDate,
                onPicked: (d) => setState(() => row.expireDate = d),
              ),
              icon: Icon(
                expired
                    ? Icons.error
                    : soon
                        ? Icons.schedule
                        : Icons.calendar_today,
                size: 14,
                color: expired
                    ? Colors.red
                    : soon
                        ? Colors.orange
                        : null,
              ),
              label: Text(
                row.expireDate != null
                    ? DateFormat.yMMMd().format(row.expireDate!)
                    : 'No date',
                style: TextStyle(
                  fontSize: 12,
                  color: expired
                      ? Colors.red
                      : soon
                          ? Colors.orange
                          : null,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: _batchRows.length > 1
                ? () {
                    _batchRows[index].dispose();
                    setState(() => _batchRows.removeAt(index));
                  }
                : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
        ],
      ),
    );
  }

  String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
}

class _PriceStat extends StatelessWidget {
  final String label;
  final String value;

  const _PriceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
