
### `add_ingredient_sheet.dart`
| Line | Banner | What's there |
| :--- | :--- | :--- |
| 22 | STATE / CONTROLLERS | All fields, controllers, flags |
| 37 | INIT / DISPOSE | `initState` pre-fills from existing item; `dispose` cleans up controllers |
| 66 | DATE PICKER | `_pickDate` method |
| 75 | SAVE LOGIC (edit / add / new) | `_save` method with three sub-branches: |
| - | **BRANCH 1: EDIT EXISTING ITEM** | Updates item + appends price entry |
| - | **BRANCH 2: ADD QTY TO EXISTING ITEM** | Combines qty + appends price entry |
| - | **BRANCH 3: BRAND-NEW INGREDIENT** | Creates item + optional first price entry |
| 163 | PRICE HISTORY — SUMMARY & LIST | `_buildPriceSummary` and `_buildPriceHistoryList` |
| 258 | BUILD | Main `build` method |
| - | ---- NAME FIELD ---- | Autocomplete / text field |
| - | ---- QUANTITY / UNIT ROW ---- | Qty input + unit dropdown |
| - | ---- EXPIRATION DATE BUTTON ---- | Date picker button |
| - | ---- PRICE HISTORY DISPLAY ---- | Summary + expandable list (edit mode) |
| - | ---- ADD PRICE ENTRY FIELDS ---- | Store + price inputs (all modes) |
| - | ---- SAVE BUTTON ---- | FilledButton |
| 475 | HELPER WIDGET: _PriceStat | Private stat tile widget |