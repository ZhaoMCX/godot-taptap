class_name TapCloudSaveLocalSnapshot
extends RefCounted

var exists: bool
var summary: String
var playtime_seconds: int
var modified_time: int
var fingerprint: String
var cover_path: String


func _init(
		has_data: bool = false,
		description: String = "",
		playtime: int = 0,
		updated_at: int = 0,
		content_fingerprint: String = "",
		image_path: String = "",
) -> void:
	exists = has_data
	summary = description
	playtime_seconds = playtime
	modified_time = updated_at
	fingerprint = content_fingerprint
	cover_path = image_path
