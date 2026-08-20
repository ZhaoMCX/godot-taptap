class_name TapCloudSaveArchiveListReceivedEvent
extends GFEvent

const TYPE := &"godot_taptap.cloud_save.archive_list_received"

var archives: Array[TapCloudSaveArchiveSnapshot]


func _init(
		values: Array[TapCloudSaveArchiveSnapshot],
		command_id: String,
		event_id: String = "",
) -> void:
	super(command_id, event_id)
	archives = values.duplicate()


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	var payload_archives: Array[Dictionary] = []
	for archive: TapCloudSaveArchiveSnapshot in archives:
		payload_archives.append(archive.to_dictionary())
	return {"archives": payload_archives}
