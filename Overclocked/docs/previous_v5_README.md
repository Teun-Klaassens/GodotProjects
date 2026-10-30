# OVERCLOCKED — Complete Systems Prototype (Godot 4.3+)

This is the larger playable implementation of the agreed design, built as a standalone Godot 4 project. It replaces the v4 project; do not copy individual scripts into v4.

## Start
1. Extract the zip, import **project.godot** in Godot 4.3 or later.
2. Press **F5** to run the **main.tscn** scene.
3. Click **Start demo factory** (left panel) to instantly get a functioning iron production chain. The miner, smelter and constructor need time to feed the hub. You can also start from an empty map, create your own layouts, or click the Save/Load buttons.
4. Place buildings, power poles and belts using the left menu.

## Controls
- WASD: camera movement; MMB drag: pan; mouse wheel: zoom.
- Left click: place selected building, or drag from start to end when conveyor selected.
- Right click: inspect a machine; right click while drawing a belt cancels the path.
- `1` belt, `2` miner, `3` smelter, `4` constructor, `5` erase, `6` hub, `7` assembler, `8` storage, `9` starter generator, `0` coal generator, `P` power pole, `H` hub, `X` erase.
- `R`: 90° rotation; `G`: show/hide grid; `E`: toggle inspected machine; `Space`: pause; `I`: toggle inventory; `Tab`: toggle historic stats; `M`: background music on/off; `Esc`: cancel/close inspector; `Delete`: demolish under cursor.
- `F5` **inside the running game**: save; `F9` load (also available as UI buttons).

## All implemented systems
- **Build grid:** 40×30 world with 64px cells, variable footprints, 90° rotation, validity preview, demolition and 100% refunds.
- **Automatic belt paths:** breadth-first shortest route around machines, existing belt interiors and unbuildable land. Each belt carries a single item at a time. Corner tiles use the uploaded clockwise and counterclockwise loop animation sheets. No splitters or mergers yet.
- **Items and logistics:** animated belt transport, per-cell item movement, blocking, fixed machine input/output ports, three rear input ports on hubs/assemblers to handle multi-product recipes.
- **Resources:** unlimited stationary iron, copper, limestone and coal deposits; miners require placement over a deposit and yield one resource/s while powered.
- **Recipes:** smelter (iron/copper ingots); constructor (iron plates, iron rods, copper wire, concrete); assembler (reinforced plates, circuits), selectable in a machine's inspector. Storage buffers items and outputs them along outgoing belts.
- **Power:** starter generator 60kW, coal generator 150kW (requires belt-fed coal fuel, one per ~12s) and power poles. Generators/poles join networks at 7-tile range, machines join at 6-tile range. An overloaded network powers down its connected consumers until capacity is restored. Machines have enabled/disabled toggles.
- **Economy:** single player building inventory with material costs, full refunds, output collection, and delivered items returned to inventory. Starter supplies sufficient for initial factory building and experimentation.
- **Goals:** 20 plates; 30 wire + 20 rods; 15 reinforced plates + 10 circuits + 20 concrete; then endless repeatable delivery contracts. Unlocks recipes/machines between milestones.
- **UI:** categorized build hotkeys, building costs on hover, machine inspector (buffers, status, recipe choice), materials panel, power/production/delivery HUD and 90s time-series graph.
- **Save/load:** `user://overclocked_save_v5.json` with buildings, belts, recipes, buffers, transported items, inventory, milestones, camera and history. Autosave every 60 seconds and on quit. v4 saves are NOT compatible.
- **Art/audio:** only cropped sprites from the uploaded Aseprite sheets (including animated loop corners), simple procedurally drawn landscape/ore deposits, original locally generated soft background loop (toggle M), simple original placement sound.

## Tests (open scene and press F6)
- `scenes/tests/building_test.tscn`: footprints, deposits, routes, loop corners and port alignment.
- `scenes/tests/simulation_test.tscn`: powered miner → smelter → constructor → hub, delivery and history.
- `scenes/tests/progress_save_test.tscn`: milestone/endless flow and save/load round trip.

## Known limits / future polish
- This is a big integrated **prototype**, not a shipping-quality game; Godot executable is not available in the creation environment, so the project has **not been launched or engine-verified** here. The tests are included but are not claimed to have passed.
- Belt routing is basic Manhattan shortest path; it avoids crossing existing belts, and supports connecting to existing endpoints, but it does not implement splitters, mergers, elevation or belt direction editing after placement.
- Multi-input machines accept items arriving at any of their rear ports, and recipe switching keeps input items in buffer. There is no recipe filter at each port.
- Some custom machine sprites are extracted from the uploaded master spritesheet; these are different tiles from the originally designed machine structures, scaled to larger grid footprints.
- Environmental sprites are procedurally drawn to honor your preference not to bring in new external art.
- Save v5 format is intentionally incompatible with v4 due to changed item and buffer data structures.
- Input/output restrictions and 60kW startup power make machine placement meaningful. Every machine shows its power and buffers when inspected.

## Code architecture
- `scripts/components/factory_data.gd`: recipe/building registry and progression unlocks.
- `scripts/components/build_grid.gd`: footprints, placement, demolition, ports, BFS pathing.
- `scripts/components/belt_visuals.gd`: animated corner and straight sprites from original assets.
- `scripts/components/power_network.gd`: connected power supply/demand.
- `scripts/components/factory_simulation.gd`: item and production simulation, storage, coal fuel, production history.
- `scripts/components/milestone_progress.gd`: staged and endless goals.
- `scripts/components/save_manager.gd`: JSON persistence.
- `scripts/components/history_chart.gd`: historical graph widget.
- `scripts/main.gd`: UI/input/rendering, inventory, orchestration.

## License
Included sprites are adaptations/crops of the *user-supplied* artwork; check the original sprite pack's license before distributing this game. New WAV sounds are synthesized original audio generated for this project. No third-party assets have been downloaded.


## v5.1 class-resolution and conveyor-renderer fix

This patch adds the missing `scripts/components/belt_visuals.gd` file and replaces
implicit global `class_name` dependencies with explicit `preload(...)` constants
in every dependent script. The class-loader error cascade should be resolved.

**Clean import after extracting:** Close Godot, unzip the updated project to a NEW
folder, import that folder's `project.godot`, allow the filesystem scan to finish,
then run the main scene. Avoid merging this ZIP over an old project's `.godot` cache.

There is no Godot executable available in the build environment, so this patch
has static checks only, not a Godot editor/runtime verification.

