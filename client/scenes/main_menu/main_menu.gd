extends Control


func _ready() -> void:
	Network.connect_to_server()
	Network.lobby_created.connect(_lobby_created)

func _on_creat_btn_pressed() -> void:
	%RoomCreatePanel.visible = !%RoomCreatePanel.visible

func _lobby_created():
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")


func _on_join_btn_pressed() -> void:
	%LobbiesPanel.visible = !%LobbiesPanel.visible


func _on_quit_btn_pressed() -> void:
	get_tree().quit()
