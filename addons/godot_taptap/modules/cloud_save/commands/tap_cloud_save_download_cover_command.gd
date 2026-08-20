class_name TapCloudSaveDownloadCoverCommand
extends GFCommand

const TYPE := &"godot_taptap.cloud_save.download_cover"

var uuid: String
var file_id: String
var destination_path: String


func _init(
		archive_uuid: String,
		archive_file_id: String,
		target_path: String,
		id: String = "",
) -> void:
	super(id)
	uuid = archive_uuid
	file_id = archive_file_id
	destination_path = target_path


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"uuid": uuid, "file_id": file_id, "destination_path": destination_path}
