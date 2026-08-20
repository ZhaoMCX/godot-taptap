class_name TapSdkInitializedEvent
extends GFEvent

const TYPE := &"godot_taptap.core.initialized"


func _init(command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)


func get_message_type() -> StringName:
	return TYPE
