class_name GFCommand
extends RefCounted

const BASE_TYPE := &"godot_framework.command"

var command_id: String:
	get:
		return _command_id

var _command_id: String


func _init(id: String = "") -> void:
	_command_id = GFId.new_id() if id.is_empty() else id


## Override and return a stable protocol name. Do not derive it from the script name.
func get_message_type() -> StringName:
	return BASE_TYPE


## Override with network-safe data only. Never include Object or Node references.
func to_payload() -> Dictionary:
	return {}
