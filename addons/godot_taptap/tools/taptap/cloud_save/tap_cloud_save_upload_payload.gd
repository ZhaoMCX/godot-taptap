class_name TapCloudSaveUploadPayload
extends RefCounted

var archive_path: String
var cover_path: String
var summary: String
var extra: String
var playtime_seconds: int
var fingerprint: String


func _init(
		data_path: String = "",
		image_path: String = "",
		description: String = "",
		extra_data: String = "",
		playtime: int = 0,
		content_fingerprint: String = "",
) -> void:
	archive_path = data_path
	cover_path = image_path
	summary = description
	extra = extra_data
	playtime_seconds = playtime
	fingerprint = content_fingerprint
