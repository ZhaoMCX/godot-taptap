class_name TapCloudSaveCoverDownloadedEvent
extends GFEvent

const TYPE := &"godot_taptap.cloud_save.cover_downloaded"

var destination_path: String


func _init(path: String, command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)
	destination_path = path


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"destination_path": destination_path}
