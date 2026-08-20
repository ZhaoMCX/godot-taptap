class_name GFEvent
extends RefCounted

const BASE_TYPE := &"godot_framework.event"

var event_id: String:
	get:
		return _event_id

var causation_id: String:
	get:
		return _causation_id

var _event_id: String
var _causation_id: String


func _init(caused_by: String = "", id: String = "") -> void:
	_causation_id = caused_by
	_event_id = GFId.new_id() if id.is_empty() else id


## Override and return a stable protocol name. Do not derive it from the script name.
func get_message_type() -> StringName:
	return BASE_TYPE


## Override with network-safe data only. Never include Object or Node references.
func to_payload() -> Dictionary:
	return {}
