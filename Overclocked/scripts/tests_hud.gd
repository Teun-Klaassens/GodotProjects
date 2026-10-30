extends Node2D
## Run with F6: verifies menu initialization and category data without relying on gameplay.
const Catalog = preload("res://scripts/ui/build_catalog.gd")
const Data = preload("res://scripts/components/factory_data.gd")

func _ready() -> void:
 var catalog: Catalog = Catalog.new()
 add_child(catalog)
 catalog.open_catalog(Data.STARTER_INVENTORY.duplicate(true),0,0)
 assert(catalog.visible, "Build catalog must open")
 assert(catalog.cards.has(1), "Conveyor card must be visible")
 assert(catalog.cards.has(8), "Storage card must be present, even if locked")
 catalog._group_clicked("Power")
 assert(catalog.cards.has(11), "Power pole must be in Power category")
 assert(catalog.cards.has(9), "Starter generator must be in Power category")
 catalog.hide_catalog()
 assert(not catalog.visible, "Catalog must close")
 print("HUD catalog smoke tests PASSED")
