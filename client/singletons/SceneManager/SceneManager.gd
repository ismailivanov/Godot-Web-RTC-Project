extends Node

var loading_scene = preload("res://singletons/SceneManager/loading.tscn")


var progress = []
var scene_loaded_status = 0
var scene : String
var scene_changed : bool = false

var MEMBERS_LOADED : Dictionary
var remote_change : bool = false

func chnage_scene(scene_path : String,remote_change : bool = false):
	remote_change = remote_change
	if remote_change:
		_set_members_loaded()
		_chnage_scene_RPC.rpc(scene_path,remote_change)
	_chnage_scene_RPC(scene_path,remote_change)
func _all_loaded(my_array : Dictionary) -> bool:
	return my_array.values().all(func(value): return value)
	
func _set_members_loaded():
	MEMBERS_LOADED.clear()
	for member in Network.lobby_members:
		MEMBERS_LOADED[member] = false

@rpc("any_peer","call_remote")
func _scene_loaded_client():
	MEMBERS_LOADED[multiplayer.get_remote_sender_id()] = true
	
@rpc("any_peer","call_local")
func _chnage_scene_RPC(scene_path : String,remote_change : bool = false):
	remote_change = remote_change
	scene = scene_path
	get_tree().current_scene.queue_free()
	var loading_screen_instance = loading_scene.instantiate()
	get_tree().root.add_child(loading_screen_instance)
	get_tree().current_scene = loading_screen_instance
	
	ResourceLoader.load_threaded_request(scene_path)
	scene_changed = true
	

func _process(delta: float) -> void:
	if scene_changed:
		scene_loaded_status = ResourceLoader.load_threaded_get_status(scene,progress)
		get_tree().current_scene.set_progress(progress)
		if scene_loaded_status == ResourceLoader.THREAD_LOAD_LOADED:
			var loaded_scene = ResourceLoader.load_threaded_get(scene)
			
			if !remote_change:
				_change_the_scene(loaded_scene)
			else:
				if multiplayer.get_unique_id() == 1:
					if MEMBERS_LOADED.is_empty():
						_change_the_scene(loaded_scene)
				else:
					_scene_loaded_client.rpc_id(1)
				
		
			if _all_loaded(MEMBERS_LOADED):
				_change_the_scene(loaded_scene)
			
			
func _change_the_scene(loaded_scene):
	get_tree().change_scene_to_packed(loaded_scene)
	scene_changed = false
	print("Scene Changed to %s" % loaded_scene)
	
