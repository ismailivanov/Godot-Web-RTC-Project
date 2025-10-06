extends Node

@export_category("Debug Mode")
@export var debug_mode := false
### More to come as the game grows


func _ready() -> void:
	if debug_mode:
		Game.start_game()
