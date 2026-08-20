class_name TapCloudSaveMetadata
extends RefCounted

var name: String = ""
var summary: String = ""
var extra: String = ""
var playtime_seconds: int = 0


func _init(
		archive_name: String = "",
		archive_summary: String = "",
		archive_extra: String = "",
		archive_playtime_seconds: int = 0,
) -> void:
	name = archive_name
	summary = archive_summary
	extra = archive_extra
	playtime_seconds = archive_playtime_seconds


func to_dictionary() -> Dictionary:
	return {
		"name": name,
		"summary": summary,
		"extra": extra,
		"playtime": playtime_seconds,
	}
