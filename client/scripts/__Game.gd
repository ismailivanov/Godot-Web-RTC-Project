extends Node

## NODES ##
@onready var world_tscn := preload("res://core/world.tscn")
@onready var world : Node3D 
@onready var controller_tscn := preload("res://core/controller.tscn")
@onready var active_controllers := []

## PARAMS ##
const PLAYER_COUNT := 4


func start_game():
	### This function will eventually be called with a desired court as an argument. 
	### For now, it just adds the world and controllers in raw.
	
	for ctrl in active_controllers: ctrl.queue_free()
	active_controllers = []
	for index in range(0, PLAYER_COUNT):
		var new_controller = controller_tscn.instantiate()
		active_controllers.append(new_controller)
	
	world = world_tscn.instantiate()
	add_child(world)
	
	## Testing ##
	add_child(active_controllers[0])
	## ####### ##
