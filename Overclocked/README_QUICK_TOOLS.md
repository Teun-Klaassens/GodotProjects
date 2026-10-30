# Overclocked v7 — Quick Build & Bulldozer

This release **includes every feature from the cumulative Part 3 upgrades**, plus three direct mouse editing shortcuts. Open `project.godot` in Godot 4.3+, then press **F5**.

## New controls

| Action | Control | Behavior |
| --- | --- | --- |
| Delete one tile | Right-click and release | Deletes a belt on that tile, or the entire building occupying that tile. Refunded materials and buffered items go to the player inventory. |
| Mass delete | Hold right mouse, drag, then release | Draws a translucent red rectangular selection. Any building **touched** by the rectangle is removed once (including large buildings). Selected belt tiles are removed individually. |
| Cancel area deletion | Escape before releasing right mouse | Cancels the selection without changing the world. |
| Copy building (eyedropper) | Middle-click on a building | Selects that building type as the active tool and copies its rotation. Your next **left-click** constructs a new copy, subject to unlocks, placement checks, and costs. |
| Copy conveyor | Middle-click on a conveyor tile | Selects the conveyor-building tool. |
| Pan camera | Hold middle mouse over **empty** ground and move | Keeps middle-mouse camera panning available, without interfering with the eyedropper. |
| Inspect machine | F while hovering a machine | Opens the machine inspector (replaces the former right-click inspector). |
| Existing demolition mode | X or hotbar demolition tool | Still supports left-click deletion. |
| Undo / redo | Ctrl+Z / Ctrl+Y | An entire drag deletion is recorded as **one undo step**. |

While dragging, the selection shows which complete buildings are affected and how many machines and belts will be removed.

## Testing

Run `scenes/tests/quick_tools_test.tscn` with **F6**. The standalone test checks machine and belt picking, rotated buildings, reversed drag rectangles, out-of-bounds selections, full-cost refunds, recovery of an item carried on a belt, and one-step undo.

Other existing test scenes remain in `scenes/tests/`.

## Architecture

- `scripts/components/construction_tools.gd`: reusable selection, eyedropper, refund, and delete logic.
- `scripts/main.gd`: interprets mouse events, paints the rectangle, and commits or cancels demolition.
- `scripts/components/build_history.gd`: snapshots factory before a batch removal, enabling undo.

No sprites, recipes, saves, belts, power or production logic were changed.

**Note:** Godot is not available for engine execution here. Syntax, indentation, paths and ZIP integrity were checked, but the updated input interaction must be tested in Godot.
