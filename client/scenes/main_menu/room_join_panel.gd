extends CenterContainer


func _ready() -> void:
	visible = false


func _on_quit_btn_pressed() -> void:
	visible = false


func _on_join_room_btn_pressed() -> void:

	Network.join_room_msg(
		%RoomIDLine.text,
		Network.id,
		%PeerNameLine.text
	)
