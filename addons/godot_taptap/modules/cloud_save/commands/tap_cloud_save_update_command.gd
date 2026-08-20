class_name TapCloudSaveUpdateCommand
extends GFCommand

const TYPE := &"godot_taptap.cloud_save.update"

var uuid: String
var metadata: TapCloudSaveMetadata
var archive_path: String
var cover_path: String


func _init(
		archive_uuid: String,
		archive_metadata: TapCloudSaveMetadata,
		data_path: String,
		image_path: String = "",
		id: String = "",
) -> void:
	super(id)
	uuid = archive_uuid
	metadata = archive_metadata
	archive_path = data_path
	cover_path = image_path


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {
		"uuid": uuid,
		"metadata": {} if metadata == null else metadata.to_dictionary(),
		"archive_path": archive_path,
		"cover_path": cover_path,
	}
