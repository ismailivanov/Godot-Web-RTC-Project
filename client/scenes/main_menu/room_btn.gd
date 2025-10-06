extends PanelContainer

func set_btn(id,lobby_name):
	room_id = id
	$HBoxContainer/Label.text = lobby_name

var room_id : String
var peer_name : LineEdit 
var console 




func _on_join_btn_pressed() -> void:
	if peer_name.text.is_empty():
		console.clear()
		console.append_text("[b][color=red]! You Must Have a Name ! [/color][/b]")
		return
	if !peer_name.text.is_empty():
		Network.join_room_msg(
			room_id,
			Network.id,
			peer_name.text
		)
		print("Joining to Lobby %s" % room_id)
