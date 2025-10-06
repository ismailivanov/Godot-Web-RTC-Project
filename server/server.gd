class_name Server
extends Node
## Web Socket Signaling Server Handles Lobbies and Users and P2P Connections
##
## Manages user connections, lobby creation, and P2P signaling for multiplayer.
## Handles communication between clients to establish peer-to-peer connections.


## Message types used for communication between the signaling server and clients.
enum MESSAGE_TYPE {
	ID,             ## Used for testing the WebSocket connection
	JOIN_LOBBY,     ## Request to join a lobby
	CREATE_LOBBY,   ## Request to create a new lobby
	USER_DISCONNECTED, ## Notification that a user has disconnected
	USER_CONNECTED,    ## Notification that a user has connected
	CANDIDATE,      ## ICE candidate for establishing P2P connection
	OFFER,          ## SDP offer for P2P connection negotiation
	ANSWER,         ## SDP answer for P2P connection negotiation
	ERROR,          ## Error message
	ROOM_CREATED,   ## Confirmation that a room has been created
	LOBBY_DATA,     ## Lobbies Data 
	LOBBY_CLOSED    ## Notification that a lobby has been closed
}

var peer : WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
var port : int = 9080
var users : Array = []
var rooms : Dictionary[String,Room] = {} 


## If running with "--server" argument, prints server start message
## Connects signals for peer connection and disconnection, then starts the server
func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		print("Server started on %s" % port)
	peer.peer_connected.connect(_peer_connected)
	peer.peer_disconnected.connect(_peer_disconnected)
	start_server()

## Generates a random alphanumeric code of the specified length.
## Used primarily for creating unique room IDs.
func generate_random_code(length := 8) -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code = ""
	for i in length:
		code += charset[rng.randi_range(0, charset.length() - 1)]
	return code


## Sends the list of available rooms to the specified peer.
func send_rooms_data(peer_id : int):
	var data : Dictionary = {
		"rooms": null
	}
	var room_data : Dictionary
	for room in rooms.keys():
		room_data[rooms[room].room_name] = room 
	data["rooms"] = room_data
	send_msg(MESSAGE_TYPE.LOBBY_DATA,data,peer_id)

## Creates a new Room instance with the given host and room details
## Returns the new Room object, or nothing if the room ID already exist
func create_room(_host_name:String,_room_name : String,_room_id : String, _host_id : int) -> Room:
	if rooms.has(_room_id):
		return
		
	var new_room : Room = Room.new(_room_name,_host_name,_host_id)
	rooms[_room_id] = new_room
	return new_room
	
## Adds a peer to the specified room and notifies all peers in the lobby
## Sends updated lobby info and peer connection messages to all relevant clients
func join_room(peer_id : int,peer_name : String,room_id : String):
	if !rooms.has(room_id):
		print("There is no room with [%s] this id!" % room_id)
		return
	rooms[room_id].players[peer_id] = peer_name
	
	for peer in rooms[room_id].players.keys():
		## Lobby Info
		var data : Dictionary = {
			"players": rooms[room_id].players,
			"room_id": room_id,
			"room_name":rooms[room_id].room_name
		}
		send_msg(MESSAGE_TYPE.JOIN_LOBBY,data,peer)
		
		## Sending peer id to Peers in the lobby
		var data_for_peers : Dictionary = {
			"id": peer_id
		}
		send_msg(MESSAGE_TYPE.USER_CONNECTED,data_for_peers,peer)
		
		## Sending lobby players id to the peer
		var data_for_peer : Dictionary = {
			"id": peer
		}
		send_msg(MESSAGE_TYPE.USER_CONNECTED,data_for_peer,peer_id)
		
	print("User [%s] Connected to Lobby [%s]" % [peer_id,room_id])
	
	
## Called when a peer connects to the server
## Adds the peer to the users list and sends back its assigned ID
func _peer_connected(id: int):
	print("Peer [%s] Connected To The Server" % id)
	users.append(id)
	
	send_msg(MESSAGE_TYPE.ID,{"id":id},id)
	
	
## Called when a peer disconnects from the server
## Removes the peer from the users list and aborts the lobby if the player is host
func _peer_disconnected(id : int):
	print("Peer [%s] Disconnected From Server!" % id)
	users.erase(id)
	abort_lobby(id)
	
	
## Attempts to start the server on the specified port
## Prints success or error message based on the result
func start_server():
	var err = peer.create_server(port)
	if err != OK:
		print("Server Cannot Start! Error Code:[%s]" % err)
	else:
		print("Server Started With Port %s" % port)


## Sends a message of the given type with data to the signaling server or a specific peer
## If 'id' is -1, sends to the all peers; otherwise sends directly to the peer with that id
func send_msg(type : MESSAGE_TYPE, data : Dictionary,id : int = -1):
	data["type"] = type
	if id == -1:
		var packet_message : PackedByteArray = JSON.stringify(data).to_utf8_buffer()
		peer.put_packet(packet_message)
	else:
		var packet_message : PackedByteArray = JSON.stringify(data).to_utf8_buffer()
		peer.get_peer(id).put_packet(packet_message)


## Called every frame to poll the peer for incoming packets
## If packets are available, parses and handles them accordingly
func _process(delta: float) -> void:
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var data_string : String = packet.get_string_from_utf8()
			var data = JSON.parse_string(data_string)
			if data.has("type"):
				handle_packets(data)
				
## Processes incoming signaling messages and executes corresponding actions:
## - CREATE_LOBBY: Generates a new room and notifies the host
## - JOIN_LOBBY: Adds a user to a specified room
## - OFFER / ANSWER / CANDIDATE: Forwards WebRTC signaling packets to peers
## - LOBBY_DATA: Sends current lobby data to requesting peer
## - USER_DISCONNECTED: Removes a disconnected user from the room's player list
## - LOBBY_CLOSED: Deletes the specified room
func handle_packets(data : Dictionary):
	
	match data["type"]:
		MESSAGE_TYPE.CREATE_LOBBY:
			var new_room_id : String = generate_random_code(10)
			var new_room = create_room(data["host_name"], data["room_name"], new_room_id, data["host_id"])
			print("Room Created with id [%s] Room name is [%s] Room host id is [%s] Room host name is [%s]" % [
				new_room_id, new_room.room_name, new_room.host_id, data["host_name"]
			])
			var room_data : Dictionary = {
				"room_id": new_room_id
			}
			send_msg(MESSAGE_TYPE.ROOM_CREATED, room_data, data["host_id"])
			
		MESSAGE_TYPE.JOIN_LOBBY:
			print("User [%s] Wants to Connect Room [%s]" % [data["peer_id"], data["room_id"]])
			join_room(data["peer_id"], data["peer_name"], data["room_id"])
			
		MESSAGE_TYPE.OFFER, MESSAGE_TYPE.ANSWER, MESSAGE_TYPE.CANDIDATE:
			var packet_message : PackedByteArray = JSON.stringify(data).to_utf8_buffer()
			print("source id is %s Message Data: %s" % [data["orgPeer"], data])
			peer.get_peer(data["peer"]).put_packet(packet_message)
			
		MESSAGE_TYPE.LOBBY_DATA:
			print("Sending Lobbies Data")
			send_rooms_data(data["peer_id"])
			
		MESSAGE_TYPE.USER_DISCONNECTED:
			if rooms.has(data["room_id"]):
				rooms[data["room_id"]].players.erase(int(data["peer_id"]))
				
		MESSAGE_TYPE.LOBBY_CLOSED:
			rooms.erase(data["room_id"])


## Aborts the lobby hosted by the given peer ID
## Notifies all players in those lobbies that the lobby is closed
## Then removes the lobby from the rooms dictionary
func abort_lobby(id):
	for room in rooms.keys():
		if rooms[room].host_id == id:
			
			for peer in rooms[room].players:
				send_msg(MESSAGE_TYPE.LOBBY_CLOSED,{},peer)
				
			rooms.erase(room)
			print("Lobby %s Aborted : HostId: %s" % [room,id])
			
			
## Represents a multiplayer room with a host, players, and a room name
class Room:
	var host_id : int
	var players : Dictionary[int,String] # Maps player IDs to player names 
	var room_name : String
	
	func _init(_room_name,_host_name : String,_host_id :int) -> void:
		# Initializes the room and adds the host as the first player
		host_id = _host_id
		room_name = _room_name
		add_player(_host_name,host_id)
	
	func add_player(player_name : String,id : int):
		# Adds a player to the room
		players[id] = player_name
