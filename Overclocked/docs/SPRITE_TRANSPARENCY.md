# Building sprite transparency

The original uploaded sprites are used as RGBA textures. The game now draws each building directly on the world without any opaque backing tile. The dark strokes inside many sprites are their pixel-art **outlines**, not a black background layer.

A small translucent contact shadow is drawn beneath each building, and visible port indicators appear only when a building is inspected or Shift is held.

Original sprite alpha fractions (diagnostic; zero means the crop itself is fully opaque because that machine is a full rectangular graphic):

- `assembler`: 7.8% fully transparent pixels
- `coal_generator`: 1.0% fully transparent pixels
- `constructor`: 0.0% fully transparent pixels
- `generator`: 0.8% fully transparent pixels
- `hub`: 20.3% fully transparent pixels
- `item_circuit`: 1.5% fully transparent pixels
- `item_coal`: 1.0% fully transparent pixels
- `item_concrete`: 0.0% fully transparent pixels
- `item_copper_ingot`: 0.0% fully transparent pixels
- `item_copper_ore`: 0.0% fully transparent pixels
- `item_copper_wire`: 0.0% fully transparent pixels
- `item_iron_ingot`: 0.0% fully transparent pixels
- `item_iron_ore`: 0.0% fully transparent pixels
- `item_iron_plate`: 0.0% fully transparent pixels
- `item_iron_rod`: 0.0% fully transparent pixels
- `item_limestone`: 0.0% fully transparent pixels
- `item_reinforced_plate`: 0.0% fully transparent pixels
- `miner`: 20.4% fully transparent pixels
- `power_pole`: 3.9% fully transparent pixels
- `power_wire`: 30.0% fully transparent pixels
- `smelter`: 20.4% fully transparent pixels
- `storage`: 0.0% fully transparent pixels
