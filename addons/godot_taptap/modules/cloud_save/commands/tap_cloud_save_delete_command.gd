class_name TapCloudSaveDeleteCommand
extends GFCommand

const TYPE := &"godot_taptap.cloud_save.delete"

var uuid: String


func _init(archive_uuid: String, id: String = "") -> void:
	super(id)
	uuid = archive_uuid


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"uuid": uuid}
