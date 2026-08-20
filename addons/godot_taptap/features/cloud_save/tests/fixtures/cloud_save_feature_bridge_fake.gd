class_name CloudSaveFeatureBridgeFake
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

var archives: Array[Dictionary] = []
var fail_next_list := false
var hold_list := false
var hold_cover := false
var last_kind := ""
var _sequence := 10


func initialize(_payload_json: String) -> bool:
	return true


func cloud_save_list() -> bool:
	last_kind = "list"
	if hold_list:
		return true
	if fail_next_list:
		fail_next_list = false
		cloud_save_request_failed.emit(400006, "list failed")
	else:
		cloud_save_archive_list_received.emit(JSON.stringify(archives))
	return true


func cloud_save_create(metadata_json: String, archive_path: String, cover_path: String) -> bool:
	last_kind = "create"
	var metadata: Dictionary = JSON.parse_string(metadata_json)
	var archive := make_archive(str(metadata.name), "archive-%d" % _sequence)
	_sequence += 1
	archive.summary = str(metadata.summary)
	archive.extra = str(metadata.extra)
	archive.playtime = int(metadata.playtime)
	archive.save_size = FileAccess.get_file_as_bytes(archive_path).size()
	archive.cover_size = 0 if cover_path.is_empty() else FileAccess.get_file_as_bytes(cover_path).size()
	archives.append(archive)
	cloud_save_archive_created.emit(JSON.stringify(archive))
	return true


func cloud_save_update(
		uuid: String,
		metadata_json: String,
		archive_path: String,
		cover_path: String,
) -> bool:
	last_kind = "update"
	var metadata: Dictionary = JSON.parse_string(metadata_json)
	var archive := make_archive(str(metadata.name), uuid)
	archive.file_id = "updated-file"
	archive.summary = str(metadata.summary)
	archive.extra = str(metadata.extra)
	archive.playtime = int(metadata.playtime)
	archive.save_size = FileAccess.get_file_as_bytes(archive_path).size()
	archive.cover_size = 0 if cover_path.is_empty() else FileAccess.get_file_as_bytes(cover_path).size()
	for index: int in archives.size():
		if str(archives[index].uuid) == uuid:
			archives[index] = archive
	cloud_save_archive_updated.emit(JSON.stringify(archive))
	return true


func cloud_save_download_data(_uuid: String, _file_id: String, destination_path: String) -> bool:
	last_kind = "download_data"
	DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	var file := FileAccess.open(destination_path, FileAccess.WRITE)
	if file != null:
		file.store_string("downloaded")
		file.close()
	cloud_save_data_downloaded.emit()
	return true


func cloud_save_download_cover(_uuid: String, _file_id: String, _destination_path: String) -> bool:
	last_kind = "download_cover"
	if not hold_cover:
		cloud_save_cover_downloaded.emit()
	return true


func cloud_save_delete(uuid: String) -> bool:
	last_kind = "delete"
	for index: int in range(archives.size() - 1, -1, -1):
		if str(archives[index].uuid) == uuid:
			archives.remove_at(index)
	# TapTap 真机删除成功响应只保证 UUID；不得在测试中虚构 name/file_id。
	cloud_save_archive_deleted.emit(JSON.stringify({"uuid": uuid}))
	return true


func complete_cover() -> void:
	hold_cover = false
	cloud_save_cover_downloaded.emit()


func complete_list() -> void:
	hold_list = false
	cloud_save_archive_list_received.emit(JSON.stringify(archives))


func make_archive(name: String = "slot_1", uuid: String = "archive-1") -> Dictionary:
	return {
		"uuid": uuid,
		"file_id": "file-1",
		"name": name,
		"summary": "云端序章",
		"extra": "",
		"playtime": 120,
		"save_size": 4,
		"cover_size": 0,
		"created_time": 100,
		"modified_time": 100,
	}
