extends CenterContainer

@export var room_btn = preload("res://scenes/main_menu/room_btn.tscn")
@onready var lobbies = %Lobbies
func _ready() -> void:
	Network.lobby_data_updated.connect(data_updated)



func data_updated(data):
	var room_data : Dictionary = data["rooms"]
	print(room_data)
	for room in room_data.keys():
		var instance_room_btn = room_btn.instantiate()
		instance_room_btn.peer_name = %PeerNameLine
		instance_room_btn.console = %JoinRoomConsole
		instance_room_btn.set_btn(room_data[room],room)
		lobbies.add_child(instance_room_btn)
		
func _on_refresh_btn_pressed() -> void:
	for old_lobbies in lobbies.get_children():
		if old_lobbies is PanelContainer:
			old_lobbies.queue_free()
	Network.get_lobbies_data()


func _on_quit_btn_pressed() -> void:
	visible = false
