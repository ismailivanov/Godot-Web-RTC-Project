extends CenterContainer


func _ready() -> void:
	visible = false


func _on_quit_btn_pressed() -> void:
	visible = false


func _on_create_room_btn_pressed() -> void:
	if %HostNameLine.text.is_empty():
		%CreateRoomConsole.clear()
		%CreateRoomConsole.append_text("[b][color=red]! You Create Room Without Name ! [/color][/b]")
		return
	if  %RoomNameLine.text.is_empty():
		%CreateRoomConsole.clear()
		%CreateRoomConsole.append_text("[b][color=red]! You Create Room Without Room Name ! [/color][/b]")
		return
	
	%CreateRoomConsole.clear()
	Network.create_room_msg(%RoomNameLine.text,Network.id,%HostNameLine.text)
	Network.lobby_name = %RoomNameLine.text
	Network.peer_name = %HostNameLine.text
