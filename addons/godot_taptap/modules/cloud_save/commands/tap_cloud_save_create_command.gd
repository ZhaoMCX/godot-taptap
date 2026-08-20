class_name TapCloudSaveCreateCommand
extends GFCommand

const TYPE := &"godot_taptap.cloud_save.create"

var metadata: TapCloudSaveMetadata
var archive_path: String
var cover_path: String


func _init(
		archive_metadata: TapCloudSaveMetadata,
		data_path: String,
		image_path: String = "",
		id: String = "",
) -> void:
	super(id)
	metadata = archive_metadata
	archive_path = data_path
	cover_path = image_path


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {
		"metadata": {} if metadata == null else metadata.to_dictionary(),
		"archive_path": archive_path,
		"cover_path": cover_path,
	}
