extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	%PeerIDLine.text = str(Network.id)
	%LobbyOwnerCheckBox.button_pressed = Network.lobby_owner
	%LobbySize.value = Network.lobby_members.size()
	%LobbyId.text = str(Network.lobby_id)




func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_F1 and event.pressed:
			print(multiplayer.multiplayer_peer.get_peers())
