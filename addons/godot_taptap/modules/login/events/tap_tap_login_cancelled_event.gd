class_name TapTapLoginCancelledEvent
extends GFEvent

const TYPE := &"godot_taptap.login.cancelled"


func _init(command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)


func get_message_type() -> StringName:
	return TYPE
