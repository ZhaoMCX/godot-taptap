class_name TapCloudSaveArchiveSnapshot
extends RefCounted

var uuid: String = ""
var file_id: String = ""
var name: String = ""
var summary: String = ""
var extra: String = ""
var playtime_seconds: int = 0
var save_size: int = 0
var cover_size: int = 0
var created_time: int = 0
var modified_time: int = 0


static func from_dictionary(data: Dictionary) -> TapCloudSaveArchiveSnapshot:
	var snapshot := TapCloudSaveArchiveSnapshot.new()
	snapshot.uuid = str(data.get("uuid", ""))
	snapshot.file_id = str(data.get("file_id", ""))
	snapshot.name = str(data.get("name", ""))
	snapshot.summary = str(data.get("summary", ""))
	snapshot.extra = str(data.get("extra", ""))
	snapshot.playtime_seconds = int(data.get("playtime", 0))
	snapshot.save_size = int(data.get("save_size", 0))
	snapshot.cover_size = int(data.get("cover_size", 0))
	snapshot.created_time = int(data.get("created_time", 0))
	snapshot.modified_time = int(data.get("modified_time", 0))
	return snapshot


func to_dictionary() -> Dictionary:
	return {
		"uuid": uuid,
		"file_id": file_id,
		"name": name,
		"summary": summary,
		"extra": extra,
		"playtime": playtime_seconds,
		"save_size": save_size,
		"cover_size": cover_size,
		"created_time": created_time,
		"modified_time": modified_time,
	}
