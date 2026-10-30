# Features and what to test

Legend: Implemented = code/assets included; Godot runtime testing still required.

| Feature | Status | Manual test |
|---|---|---|
| Pan/zoom camera | Implemented | WASD, MMB, wheel |
| Landscape, rocks, water, cliffs | Implemented | Scroll around, try building on water/cliff |
| World iron/copper/limestone/coal deposits | Implemented | Select miner over marked deposit |
| 64px grid, multi-tile footprint, R rotation | Implemented | Place/rotate buildings |
| Green/red valid placement preview | Implemented | Hover blocked tiles |
| Inventory and material costs | Implemented | Build and inspect inventory |
| Demolish and full resource refunds | Implemented | Select X/5 and click |
| Click-drag shortest belt routing | Implemented | Drag belt around a building |
| Uploaded animated straight/loop corner artwork | Implemented | Build an L-shaped path and look at corner |
| Individual item transport + backpressure | Implemented | Start demo, disconnect a belt then reconnect |
| Machine ports incl. 3 rear inputs for hub/assembler | Implemented | Inspect rear yellow ports |
| Miner, smelter, constructor, assembler, storage | Implemented | Build production chain, set recipe |
| Machine recipe selector / buffers | Implemented | Right click and change recipes |
| Power poles, 60kW generator, 150kW fueled coal generator | Implemented | Observe red unpowered machines and power HUD |
| Power network overload cutoff | Implemented | Add enough consumers to overdraw |
| Three delivery milestones / unlocks | Implemented | Send required items to hub |
| Endless repeatable delivery goals | Implemented | Complete milestone 3 and another contract |
| Production, consumption, delivery and power graphs | Implemented | Press Tab |
| Manual save/load, 60-second autosave | Implemented | Save, quit, reopen and load |
| Basic interaction/build audio + soft ambient soundtrack | Implemented | Place building; press M |
| Small standalone test scenes | Implemented | F6 on scenes/tests/*.tscn |
| Splitters/mergers | Not implemented (explicitly deferred) | Not in original MVP |
| End-user polish/Steam-ready menus | Not implemented | Outside assignment prototype scope |

If an error appears in Godot, copy the *full error with filename and line number*. All code is inside scripts/ and split by system to make fixes straightforward.

### v6 HUD regression checklist
- [ ] B opens/closes centered build catalog; Search filters all building types.
- [ ] Click Logistics, Production, Power, Special and Tools; building thumbnails and descriptions change.
- [ ] Select a building and place it in the world; R rotates; costs and unlocks still work.
- [ ] Assign a building to the highlighted hotbar slot; 1–9/0 select it and the assignment persists after restarting.
- [ ] Build a power pole near a generator and machines: visible yellow cable sprites connect them. V toggles wires.
- [ ] Machine artwork appears over grass without a colored backing rectangle.
- [ ] I opens inventory; Tab opens chart; right-click inspects a machine; F5 saves and F9 loads.
- [ ] Run `scenes/tests/hud_test.tscn` with F6 (plus all v5 test scenes).

### Parts 2 + 3 tests

- [ ] In DEMO, orange cables connect generator, poles, and powered production machines.
- [ ] V toggles cables but **does not** disable electricity.
- [ ] Moving/building/demolishing poles automatically changes cable paths.
- [ ] Sprite artwork rests on grass with no opaque backing colored tiles.
- [ ] Hold Shift for port markers; right-click a machine to keep its ports visible.
- [ ] B opens the full build catalog; building thumbnails/costs and hotbar still work.
- [ ] Run `scenes/tests/power_wires_test.tscn` with F6.

- [ ] v7: Right-click a machine/belt to delete it and refund materials.
- [ ] v7: Right-click drag a rectangle and release to delete all touched machines / selected belts.
- [ ] v7: Press Escape while right-dragging to cancel.
- [ ] v7: Middle-click a rotated machine to select the same type and rotation.
- [ ] v7: Middle-click a belt to choose conveyor; middle-drag empty grass still pans.
- [ ] v7: Press F to inspect. Undo an entire mass deletion with one Ctrl+Z.
- [ ] v7: Run quick_tools_test.tscn with F6.
