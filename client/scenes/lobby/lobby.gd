extends Control


#func _show():
	#visible = true
	#get_tree().current_scene.visible = false
	#initialized.emit()
	#
#func _close():
	#visible = false
	#get_tree().current_scene.visible = true
	#uninitialize.emit()
	
var player_name_lbl : PackedScene = preload("res://scenes/lobby/player_name_label.tscn")

func _ready() -> void:
	
	Network.peer_joined.connect(_peer_joined)
	Network.peer_exited.connect(_peer_exited)
	
	%RoomIDLabel.text = ("ROOM ID: [i]%s[/i] " % Network.lobby_id)
	%RoomNameLabel.text = Network.lobby_name 
	get_members()


func _peer_joined(id: int):
	get_members()
	
func _peer_exited(id: int):
	get_members()
	
func get_members():
	for peer_label in %PlayerNamesCont.get_children():
		peer_label.queue_free()
	
	for peer_id in Network.lobby_members.keys():
		var instance_player_lbl : Label = player_name_lbl.instantiate()
		instance_player_lbl.text = Network.lobby_members[peer_id]
		%PlayerNamesCont.add_child(instance_player_lbl)
		instance_player_lbl.name = str(peer_id)
func _on_room_id_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			DisplayServer.clipboard_set(%RoomIDLabel.get_parsed_text().replace("ROOM ID:", "").strip_edges())


func _on_room_id_label_mouse_entered() -> void:
	%RoomIDLabel.text = ("ROOM ID: [i][u]%s[/u][/i]" % Network.lobby_id)


func _on_room_id_label_mouse_exited() -> void:
	%RoomIDLabel.text = ("ROOM ID: [i]%s[/i] " % Network.lobby_id)
	
@rpc("any_peer","call_remote")
func ping():
	print("ping from %s" % multiplayer.get_remote_sender_id())


func _on_ping_btn_pressed() -> void:
	ping.rpc()


func _on_quit_lobby_btn_pressed() -> void:
	Network.exit_lobby()
