# Overclocked — HUD Parts 2 + 3 Combined

This is a **complete Godot 4.3+ project**, based on the Part 1 HUD project with the build catalog, search, building thumbnails, detailed descriptions, costs, and persistent 10-slot hotbar.

## What changed

### Part 2 — Power wires
- Automatically draw **yellow/orange power-cable sprites** between poles, generators and electrically connected machines.
- Connections use the **same distances** as the electrical simulation: power sources/poles link within 7 grid cells and consumers link to the nearest network node within 6.
- Each power-network edge is drawn once (no spaghetti of duplicate lines). Cables have a slight downward curve and connector caps.
- Cables on overloaded or unpowered consumers appear muted.
- Press **V** to show/hide cables without changing the underlying electricity simulation.
- `scripts/components/power_wires.gd` contains reusable connectivity and rendering methods.

### Part 3 — World visual and HUD polish
- Removed all former **solid colored backing rectangles** behind placed machines. Their real user-supplied PNG sprites now sit directly over green grass.
- Added a small semi-transparent contact shadow under each machine (not a solid panel).
- Input/output markers only appear when inspecting a building or while holding **Shift**, keeping the world uncluttered.
- Unpowered consumers display a small red status indicator.
- Retained Part 1's dark modern **B** build catalog, thumbnails, search, power descriptions, construction costs, bottom hotbar and inventory/production drawers.

## Install

1. Extract the ZIP into a **new folder**, not on top of your older project.
2. Open `project.godot` in Godot 4.3 or newer.
3. Press **F5** to play. Press **DEMO** to spawn an iron factory with a generator, two poles and electric consumers.
4. Observe cables between them; press **V** to toggle. Hold **Shift** to reveal machine input/output markers.
5. Press **B** to open the build catalog and verify that Part 1 still works.

## Controls

| Input | Function |
|---|---|
| B | Build catalog |
| V | Show/hide power wires |
| Shift (hold) | Show machine input/output ports |
| Right click | Inspect machine |
| 1–9, 0 | Hotbar slots |
| R | Rotate building |
| Left click | Place building / drag belt |
| WASD / Middle mouse / Scroll | Camera pan / drag / zoom |
| I / Tab | Inventory / statistics |
| F5 / F9 (in game) | Save / load |
| Space | Pause |

For a standalone cable test, open `scenes/tests/power_wires_test.tscn` and run it with **F6**. The Part 1 HUD test is `scenes/tests/hud_test.tscn`.

**Engine limitation:** Godot is not installed in this environment, so this project has not been executed or visually verified in-engine. Static project-path checks have been run. The art stays pixel-art from your uploaded sprite sheets; no external building sprites were introduced.


See `README_UPGRADES.md` for the 3-part release, controls and tests.


## New in v7 — right-drag bulldozer and middle-click eyedropper

See [README_QUICK_TOOLS.md](README_QUICK_TOOLS.md). **Right-click** deletes, **right-drag** previews and mass deletes, **middle-click** copies a building type and rotation (or conveyor), **F** inspects machines, and **Ctrl+Z** undoes the whole selection. Middle-drag pans when pressed over empty ground.
