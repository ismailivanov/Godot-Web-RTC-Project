class_name Client
extends Node
## Core network manager responsible for handling all P2P connections
## and communication with the signaling server.
##
## Handles tasks such as:
## - Creating and joining lobbies
## - Retrieving lobby data
## - Establishing and managing peer-to-peer connections


## Emitted when lobby data is received from the signaling server
signal lobby_data_updated(data)
signal peer_joined(id : int)
signal peer_exited(id : int)
signal lobby_created()

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
var rtc_peer : WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()
var id : int = -1 
var peer_name : String = ""
var lobby_owner : bool = false
var lobby_id : String = ""
var lobby_members : Dictionary
var lobby_name : String = ""

## Signaling Server URL
var server_url : String = "ws://127.0.0.1"


func _ready() -> void:
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)


func RTCServerConnected():
	print("RTC Server Connected")


func RTCPeerConnected(id:int):
	print("RTC Peer Connected %s" % id)

## Handles the disconnection of a RTC peer.
## Removes the peer from lobby members, notifies the signaling server,
## and emits a signal indicating the peer has exited.
func RTCPeerDisconnected(id:int):
	
	lobby_members.erase(str(id))
	## Message for removing user from the Signaling Server 
	var data : Dictionary = {
		"peer_id": str(id),
		"room_id": lobby_id
	}
	send_msg(MESSAGE_TYPE.USER_DISCONNECTED,data)
	
	peer_exited.emit(id)
	print("%s :: RTC Peer Disconnected %s" % [self.id,id] )


## Clears all lobby-related data (ID, members, name, and ownership status)
func clear_lobby_data():
	lobby_id = ""
	lobby_members.clear()
	lobby_name = ""
	lobby_owner = false
	
	
## Connects to the WebSocket server using the given URL. 
## If empty, it will use the default local IP address.
func connect_to_server(url: String = server_url):
	var err = peer.create_client(url)
	if err != OK:
		print("Client Cannot Start! Error Code: [%s]" % err)
	else:
		print("Client Started")


## Sends a message to the WebSocket (Signaling) Server
## The server handles the message based on its "type" field
func send_msg(type: MESSAGE_TYPE, data: Dictionary):
	data["type"] = type  # Add the message type to the payload

	var packet_message: PackedByteArray = JSON.stringify(data).to_utf8_buffer()
	peer.put_packet(packet_message)  # Send the packet to the signaling server


## Creating Lobby Data and Sending it to the WebSocket (Signaling) Server
func create_room_msg(room_name : String,host_id : int,host_name : String):
	var data : Dictionary = {
		"room_name": room_name,
		"host_id": host_id,
		"host_name": host_name
	}
	send_msg(MESSAGE_TYPE.CREATE_LOBBY,data)

## Sends a request to join a lobby with the given room ID, peer ID, and peer name
func join_room_msg(room_id : String,peer_id : int, peer_name : String):
	var data : Dictionary = {
		"room_id": room_id,
		"peer_id": peer_id,
		"peer_name": peer_name
	}
	send_msg(MESSAGE_TYPE.JOIN_LOBBY, data)

## Sends a request to get lobbies from the WebSocket (Signaling) Server
func get_lobbies_data():
	var data : Dictionary = {
		"peer_id": id
	}
	send_msg(MESSAGE_TYPE.LOBBY_DATA,data)
	
## Called every frame to poll the WebSocket peer
## If there are incoming packets, decodes and passes them to the packet handler
func _process(delta: float) -> void:
	peer.poll()
	if peer.get_available_packet_count() > 0:
		var packet = peer.get_packet()
		if packet != null:
			var data_string : String = packet.get_string_from_utf8()
			var data = JSON.parse_string(data_string)
			if data.has("type"):
				handle_packets(data)
			

## Handles all packets received from the WebSocket (Signaling) server.
## Dispatches behavior based on message type (e.g., ID, room creation, lobby join, WebRTC offer/answer, etc.)
func handle_packets(data : Dictionary):
	match data["type"]:
		## When the peer connects to the signaling server. Server returns an ID to the peer
		MESSAGE_TYPE.ID:
			id = int(data["id"])
			connected(data["id"])
			print("Connected to the server with id %s" % id)
		
		## Handles confirmation when a new room is successfully created by the server.
		MESSAGE_TYPE.ROOM_CREATED:
			lobby_id = data["room_id"]
			lobby_members[id] = peer_name
			lobby_owner = true
			lobby_created.emit()
			print("Room Created with id %s" % lobby_id)
	
		## Handles the event when the client successfully joins a lobby.
		MESSAGE_TYPE.JOIN_LOBBY:
			lobby_id = data["room_id"]
			lobby_members = data["players"]
			lobby_name = data["room_name"]
			print("JOINED TO ROOM ROOMID: %s" % lobby_id)
			get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")
			# I dont want to delete this :D 
			peer_joined.emit(1)
	
		## Called when a new user connects; initializes a peer connection.
		MESSAGE_TYPE.USER_CONNECTED:
			create_peer(data)
	
		## Handles incoming ICE candidates for WebRTC peer connections.
		MESSAGE_TYPE.CANDIDATE:
			if rtc_peer.has_peer(data["orgPeer"]):
				var err = rtc_peer.get_peer(data["orgPeer"]).connection.add_ice_candidate(data.mid,int(data.index),data.sdp)
				if err != OK:
					print("Error with add_ice_candidate for %s MyID: %s ERROR_CODE: %s" % [data["orgPeer"],id,err])
				else:
					print("Got Candidate: %s MyID: %s " % [data["orgPeer"],id])
	
		## Handles incoming SDP offer for establishing a WebRTC connection.
		MESSAGE_TYPE.OFFER:
			if rtc_peer.has_peer(data["orgPeer"]):
				var err = rtc_peer.get_peer(data["orgPeer"]).connection.set_remote_description("offer",data["data"])
				if err != OK:
					print("Error with set_remote_description MYID: %s ERROR_CODE: %s" % [id,err])
				else:
					print("Sending offer MYID: %s" % id)
				
		## Handles incoming SDP answer to complete the WebRTC connection handshake.
		MESSAGE_TYPE.ANSWER:
			if rtc_peer.has_peer(data["orgPeer"]):
				rtc_peer.get_peer(data["orgPeer"]).connection.set_remote_description("answer",data["data"])
	
		## Called when user get the data about the active lobbies
		MESSAGE_TYPE.LOBBY_DATA:
			lobby_data_updated.emit(data)


# Called when the client is assigned an ID by the signaling server.
# Initializes the RTC peer mesh and sets up the multiplayer peer.
func connected(id):
	var err = rtc_peer.create_mesh(id)
	if err != OK:
		print("Error with creating rtc_peer mesh MYID: %s ERROR_CODE: %s" %[id,err])
	multiplayer.multiplayer_peer = rtc_peer


# Creates a new WebRTC peer connection for a remote peer if it is not the local client.
func create_peer(data : Dictionary):
	if !data["id"] == id:
		var peer : WebRTCPeerConnection = WebRTCPeerConnection.new()
		var config = {
			"iceServers": [
				## STUN server for NAT traversal 
				{
					"urls": ["stun:stun.relay.metered.ca:80"]
				},
				## TURN server for relay when direct connection fails
				{
					"urls": [
						"turn:global.relay.metered.ca:80"
					],
					"username": "ecedff8d956614c39baf2eb7",
					"credential": "ar8RA8KqW87PXnFr"
				}
			]
		}
		var err = peer.initialize(config)
		
		if err != OK:
			print("Failed to initialize WebRTC peer (ID: %s), error code: %d" % [data["id"], err])
		else:
			print("Initialized WebRTC peer with ID: %s (Local ID: %s)" % [data["id"], id])
		peer.session_description_created.connect(self.offerCreated.bind(data["id"]))
		peer.ice_candidate_created.connect(self.iceCandidateCreated.bind(data["id"]))
		
		rtc_peer.add_peer(peer,data["id"])
		if !lobby_owner:
			peer.create_offer()


## Called when a session description (offer/answer) is created.
## Sets the local description for the specified peer and sends it through signaling.
func offerCreated(type : String, data : String, id):
	if !rtc_peer.has_peer(id):
		print("No peer found with ID %s to send %s" % [id, type])
		return
	
	rtc_peer.get_peer(id).connection.set_local_description(type,data)
	
	if type == "offer":
		sendOffer(id,data)
	else:
		sendAnswer(id,data)
		
		
## Sends an SDP offer message to the specified peer via the signaling server.
func sendOffer(id,data):
	var message = {
		"peer": int(id),
		"orgPeer": int(self.id),
		"data":data,
		"lobby_id": lobby_id
	}
	send_msg(MESSAGE_TYPE.OFFER,message)
	
	
## Sends an SDP answer message to the specified peer via the signaling server.
func sendAnswer(id,data):
	var message = {
		"peer": int(id),
		"orgPeer": int(self.id),
		"data":data,
		"lobby_id": lobby_id
	}
	send_msg(MESSAGE_TYPE.ANSWER,message)
	
	
## Sends an ICE candidate message to the specified peer via the signaling server.
func iceCandidateCreated(midName: String, indexName: int, sdpName: String, id):
	var message = {
		"peer": id,
		"orgPeer": int(self.id),
		"mid":midName,
		"index":indexName,
		"sdp":sdpName,
		"lobby_id": lobby_id
	}
	send_msg(MESSAGE_TYPE.CANDIDATE,message)
	pass


## Handles the process of exiting the lobby.
## If the client is the lobby owner, it notifies the server and aborts the lobby.
func exit_lobby() -> bool:
	print("Exiting lobby...")
	if lobby_owner:
		var data : Dictionary = {"room_id": lobby_id}
		RPC_abort_lobby.rpc()
		send_msg(MESSAGE_TYPE.LOBBY_CLOSED,data)
		await get_tree().create_timer(0.5).timeout
		abort_lobby()

		return true
	abort_lobby()
	#
	return true


## Remote procedure call to abort the lobby, triggered by any peer reliably.
@rpc("any_peer","reliable","call_remote")
func RPC_abort_lobby():
	abort_lobby()


## Aborts the current lobby by stopping all connections, clearing lobby data,
## and returning to the main menu scene.
func abort_lobby():
	stop_connections()
	lobby_members.clear()
	lobby_id = ""
	lobby_name = ""
	lobby_owner = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


## Stops all current RTC connections, resets the peer, 
## and reinitializes the local connection. Also removes all connected peers.
func stop_connections():
	rtc_peer.close()
	rtc_peer = WebRTCMultiplayerPeer.new()
	connected(id)
	var peers = multiplayer.multiplayer_peer.get_peers()
	for peer in peers:
		multiplayer.multiplayer_peer.remove_peer(peer)
		
