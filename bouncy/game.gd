extends Node2D

@onready var left_score_label: Label = $CanvasLayer/LeftScore
@onready var right_score_label: Label = $CanvasLayer/RightScore
@onready var tiles: Node = $Tiles


func _ready() -> void:
	update_score()


func update_score() -> void:
	var left_score := 0
	var right_score := 0

	for tile in tiles.get_children():
		if tile is Tile:
			if tile.ball.is_ball_one:
				right_score += 1
			else:
				left_score += 1

	left_score_label.text = str(left_score)
	right_score_label.text = str(right_score)
