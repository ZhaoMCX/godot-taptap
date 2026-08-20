class_name CloudSaveModuleBridgeFake
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)
signal cloud_save_archive_created(archive_json: String)
signal cloud_save_archive_updated(archive_json: String)
signal cloud_save_archive_deleted(archive_json: String)
signal cloud_save_archive_list_received(archives_json: String)
signal cloud_save_data_downloaded
signal cloud_save_cover_downloaded
signal cloud_save_request_failed(native_code: int, message: String)
signal cloud_save_status(code: int)

var hold_requests := false
var next_error_code := 0
var archives: Array[Dictionary] = []
var next_uuid := 1


func initialize(_payload_json: String) -> bool:
	return true


func cloud_save_create(metadata_json: String, archive_path: String, cover_path: String) -> bool:
	if _fail_or_hold():
		return true
	var metadata: Dictionary = JSON.parse_string(metadata_json)
	var archive := _archive_from(metadata, archive_path, cover_path, "archive-%d" % next_uuid)
	next_uuid += 1
	archives.append(archive)
	cloud_save_archive_created.emit(JSON.stringify(archive))
	return true


func cloud_save_list() -> bool:
	if _fail_or_hold():
		return true
	cloud_save_archive_list_received.emit(JSON.stringify(archives))
	return true


func cloud_save_download_data(_uuid: String, _file_id: String, _destination_path: String) -> bool:
	if _fail_or_hold():
		return true
	cloud_save_data_downloaded.emit()
	return true


func cloud_save_update(
		uuid: String,
		metadata_json: String,
		archive_path: String,
		cover_path: String,
) -> bool:
	if _fail_or_hold():
		return true
	var metadata: Dictionary = JSON.parse_string(metadata_json)
	var archive := _archive_from(metadata, archive_path, cover_path, uuid)
	archive.file_id = "file-updated"
	for index: int in archives.size():
		if archives[index].uuid == uuid:
			archives[index] = archive
	cloud_save_archive_updated.emit(JSON.stringify(archive))
	return true


func cloud_save_delete(uuid: String) -> bool:
	if _fail_or_hold():
		return true
	for index: int in range(archives.size() - 1, -1, -1):
		if archives[index].uuid == uuid:
			archives.remove_at(index)
	cloud_save_archive_deleted.emit(JSON.stringify({"uuid": uuid}))
	return true


func cloud_save_download_cover(_uuid: String, _file_id: String, _destination_path: String) -> bool:
	if _fail_or_hold():
		return true
	cloud_save_cover_downloaded.emit()
	return true


func complete_list() -> void:
	hold_requests = false
	cloud_save_archive_list_received.emit(JSON.stringify(archives))


func emit_status(code: int) -> void:
	cloud_save_status.emit(code)


func _fail_or_hold() -> bool:
	if next_error_code != 0:
		var code := next_error_code
		next_error_code = 0
		cloud_save_request_failed.emit(code, "cloud save error %d" % code)
		return true
	return hold_requests


func _archive_from(
		metadata: Dictionary,
		archive_path: String,
		cover_path: String,
		uuid: String,
) -> Dictionary:
	var archive := _default_archive()
	archive.uuid = uuid
	archive.name = str(metadata.get("name", ""))
	archive.summary = str(metadata.get("summary", ""))
	archive.extra = str(metadata.get("extra", ""))
	archive.playtime = int(metadata.get("playtime", 0))
	archive.save_size = FileAccess.get_file_as_bytes(archive_path).size()
	archive.cover_size = 0 if cover_path.is_empty() else FileAccess.get_file_as_bytes(cover_path).size()
	return archive


func _default_archive() -> Dictionary:
	return {
		"uuid": "archive-1",
		"file_id": "file-1",
		"name": "slot_1",
		"summary": "summary",
		"extra": "",
		"playtime": 1,
		"save_size": 4,
		"cover_size": 0,
		"created_time": 100,
		"modified_time": 100,
	}
