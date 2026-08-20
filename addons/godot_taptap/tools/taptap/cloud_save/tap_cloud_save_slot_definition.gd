class_name TapCloudSaveSlotDefinition
extends RefCounted

var slot_id: String
var archive_name: String
var display_name: String


func _init(id: String = "", remote_name: String = "", label: String = "") -> void:
	slot_id = id
	archive_name = remote_name
	display_name = label
