class_name TapCloudSaveArchiveUpdatedEvent
extends GFEvent

const TYPE := &"godot_taptap.cloud_save.archive_updated"

var archive: TapCloudSaveArchiveSnapshot


func _init(value: TapCloudSaveArchiveSnapshot, command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)
	archive = value


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"archive": {} if archive == null else archive.to_dictionary()}
