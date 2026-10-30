# Overclocked — Godot asset preparation

These exports are made from the uploaded `.aseprite` sources. All PNGs retain alpha transparency.

## Files
- `master/frame_00.png`: complete exported master Aseprite canvas (320x3776).
- `master/original_173x2048.png`: uploaded compact preview sheet.
- `conveyors/frame_00.png` ...: 4 individual animation frames (256x224 each, 100 ms per frame).
- `conveyors/animation_strip.png`: all conveyor frames side-by-side.
- `machines/frame_00.png` ...: 16 individual frames (160x160 each, 250 ms per frame).
- `machines/animation_strip.png`: all machine frames side-by-side.
- `asset_manifest.json`: frame counts, sizes, durations and source layer names.

## Godot import
1. Copy these folders into your project's `res://assets/automation/`.
2. Set **Texture Filter = Nearest** on relevant Sprite2D/AnimatedSprite2D nodes (or project-wide Canvas Textures).
3. To animate a *whole* Aseprite canvas, use an `AnimatedSprite2D`, create a `SpriteFrames` resource and add the individual `frame_XX.png` images in order.
4. Set conveyor FPS to **10** (100 ms/frame); machine FPS to **4** (250 ms/frame).
5. IMPORTANT: The source canvases contain many separate elements/layers, so animating the whole canvas is useful for previewing but NOT a ready-made isolated belt or machine. Crop specific regions / export individual layers in Aseprite before creating production nodes. The animation strips are intentionally NOT individual machine sprites.
6. Keep a logical 64x64 placement grid independent from native artwork size.

## License
The exports preserve the uploaded artwork. Verify the original asset pack's license before redistribution; this archive does not grant a license.
