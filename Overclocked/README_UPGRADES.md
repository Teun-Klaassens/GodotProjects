# Overclocked — All selected upgrades (Parts 1–3)

Import `project.godot` in Godot 4.3+ and press F5. This cumulative release builds on the latest HUD Parts 2+3.

## Part 1 — Conveyor logistics and factory alerts
- B menu: 3-output splitter and 3-input merger, both 1×1 and rotatable with R.
- Conveyor path preview displays valid route and iron-plate cost.
- Factory alerts on N: offline power, overload, blocked belts, missing inputs/full buffers.

## Part 2 — Machine operations and construction
- Improved inspector: recipe, current input/output, progress, lifetime utilization, power usage; deposit and collect items.
- Bag sorting by quantity/name, display of 100-item stacks; transfers up to 100 at once. Bag has no fixed maximum.
- Shift + left drag machine painting, Ctrl+Z undo, Ctrl+Y redo, Ctrl+C copy machine settings, Ctrl+V paste same-type machine settings.
- K power dashboard, red overloaded network cables and network-wise supply/demand.
- TAB analytics with per-minute throughput, blocked belt and output-buffer bottlenecks.
- Faint building alignment guides.

## Part 3 — Build catalog, saves, progression and polish
- Catalog favorites, recently used, search and filters (all/unlocked/affordable); preferences persist.
- Three customizable hotbar presets switched with Ctrl+1/2/3 or PRESET; preset changes persist.
- Save slots 1–5 with names and up to three backups per slot; F6 or SLOTS opens save/load UI, F5 quick-saves selected slot, F9 quick-loads selected slot. Legacy v5 save is slot 1; autosaves use separate slot 0 and can be recovered.
- Progress bar shows current milestone completion; HUD shows next reward; delivery hub pulses on deliveries; placement ring and active-machine light animations.
- The previous user-supplied machine, conveyor and wire sprites are preserved.

## Smoke tests
Open each scene and press F6:
- `scenes/tests/logistics_alerts_test.tscn`
- `scenes/tests/operations_test.tscn`
- `scenes/tests/save_slots_test.tscn`
- Original five tests also remain.

## Important limits
- There is no Godot runtime in this environment, so syntax was inspected statically, but integration and gameplay have **not** been tested in Godot. If a parser error appears, send the first filename and line.
- Undo/redo history is per-session and does not undo production ticks or deliveries. It snapshots construction, machine buffers and bag inventory at the moment of each edit.
- Splitters round-robin across currently available outputs; mergers use one output. Existing belt crossings are still disallowed.
- Stacks are an inventory UI representation (100-item stacks), not a new physical capacity limit on the player inventory.
- Visual polish uses animation overlays on top of supplied sprites, not a new art pack.
