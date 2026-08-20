class_name TapSdkSimulatorBridge
extends RefCounted

signal initialization_succeeded
@warning_ignore("unused_signal")
signal initialization_failed(native_code: int, message: String)
signal login_succeeded(account_json: String)
@warning_ignore("unused_signal")
signal login_cancelled
@warning_ignore("unused_signal")
signal login_failed(native_code: int, message: String)
signal logout_succeeded
@warning_ignore("unused_signal")
signal logout_failed(native_code: int, message: String)
signal compliance_result(result_json: String)
signal cloud_save_archive_created(archive_json: String)
signal cloud_save_archive_updated(archive_json: String)
signal cloud_save_archive_deleted(archive_json: String)
signal cloud_save_archive_list_received(archives_json: String)
signal cloud_save_data_downloaded
signal cloud_save_cover_downloaded
signal cloud_save_request_failed(native_code: int, message: String)
signal cloud_save_status(code: int)

var _account: Dictionary = {}
var _next_compliance_code: int = TapComplianceResult.LOGIN_SUCCESS
var _cloud_archives: Dictionary = {}
var _cloud_archive_sequence := 1
var _cloud_file_sequence := 1


func initialize(_payload_json: String) -> bool:
	initialization_succeeded.emit.call_deferred()
	return true


func login(_scopes_json: String) -> bool:
	_account = {
		"open_id": "demo-open-id",
		"union_id": "demo-union-id",
		"name": "TapSDK 演示账号",
		"avatar_url": "",
		"scopes": ["public_profile"],
	}
	login_succeeded.emit.call_deferred(JSON.stringify(_account))
	return true


func get_current_account() -> String:
	return JSON.stringify(_account) if not _account.is_empty() else ""


func logout() -> bool:
	_account.clear()
	logout_succeeded.emit.call_deferred()
	return true


func start_compliance(_open_id: String) -> bool:
	var payload := JSON.stringify({"code": _next_compliance_code, "metadata": {"demo": true}})
	compliance_result.emit.call_deferred(payload)
	return true


func exit_compliance() -> bool:
	return true


func set_next_compliance_code(code: int) -> void:
	_next_compliance_code = code


func cloud_save_create(metadata_json: String, archive_path: String, cover_path: String) -> bool:
	if not _ensure_cloud_save_account():
		return true
	var metadata := _parse_dictionary(metadata_json)
	if metadata.is_empty():
		_fail_cloud_save(400009, "云存档元数据格式无效")
		return true
	var uuid := "simulator-archive-%d" % _cloud_archive_sequence
	_cloud_archive_sequence += 1
	var record := _create_cloud_record(uuid, metadata, archive_path, cover_path)
	if record.is_empty():
		return true
	_cloud_archives[uuid] = record
	cloud_save_archive_created.emit.call_deferred(JSON.stringify(record.metadata))
	return true


func cloud_save_list() -> bool:
	if not _ensure_cloud_save_account():
		return true
	var archives: Array[Dictionary] = []
	for record: Dictionary in _cloud_archives.values():
		archives.append(record.metadata)
	cloud_save_archive_list_received.emit.call_deferred(JSON.stringify(archives))
	return true


func cloud_save_download_data(uuid: String, file_id: String, destination_path: String) -> bool:
	return _download_cloud_file(uuid, file_id, destination_path, false)


func cloud_save_update(
		uuid: String,
		metadata_json: String,
		archive_path: String,
		cover_path: String,
) -> bool:
	if not _ensure_cloud_save_account():
		return true
	if not _cloud_archives.has(uuid):
		_fail_cloud_save(400002, "指定的云存档不存在")
		return true
	var metadata := _parse_dictionary(metadata_json)
	var record := _create_cloud_record(uuid, metadata, archive_path, cover_path)
	if record.is_empty():
		return true
	var previous: Dictionary = _cloud_archives[uuid]
	record.metadata.created_time = previous.metadata.created_time
	_cloud_archives[uuid] = record
	cloud_save_archive_updated.emit.call_deferred(JSON.stringify(record.metadata))
	return true


func cloud_save_delete(uuid: String) -> bool:
	if not _ensure_cloud_save_account():
		return true
	if not _cloud_archives.has(uuid):
		_fail_cloud_save(400002, "指定的云存档不存在")
		return true
	var deleted: Dictionary = _cloud_archives[uuid]
	_cloud_archives.erase(uuid)
	cloud_save_archive_deleted.emit.call_deferred(JSON.stringify(deleted.metadata))
	return true


func cloud_save_download_cover(uuid: String, file_id: String, destination_path: String) -> bool:
	return _download_cloud_file(uuid, file_id, destination_path, true)


func _ensure_cloud_save_account() -> bool:
	if not _account.is_empty():
		return true
	cloud_save_status.emit.call_deferred(TapCloudSaveStatusEvent.LOGIN_REQUIRED_CODE)
	_fail_cloud_save(TapCloudSaveStatusEvent.LOGIN_REQUIRED_CODE, "云存档需要 TapTap 登录")
	return false


func _create_cloud_record(
		uuid: String,
		metadata: Dictionary,
		archive_path: String,
		cover_path: String,
) -> Dictionary:
	if metadata.is_empty() or not FileAccess.file_exists(archive_path):
		_fail_cloud_save(400000, "云存档文件不存在或元数据无效")
		return {}
	var archive_bytes := FileAccess.get_file_as_bytes(archive_path)
	var cover_bytes := PackedByteArray()
	if not cover_path.is_empty():
		if not FileAccess.file_exists(cover_path):
			_fail_cloud_save(400000, "云存档封面不存在")
			return {}
		cover_bytes = FileAccess.get_file_as_bytes(cover_path)
	var timestamp := int(Time.get_unix_time_from_system())
	var file_id := "simulator-file-%d" % _cloud_file_sequence
	_cloud_file_sequence += 1
	return {
		"metadata": {
			"uuid": uuid,
			"file_id": file_id,
			"name": str(metadata.get("name", "")),
			"summary": str(metadata.get("summary", "")),
			"extra": str(metadata.get("extra", "")),
			"playtime": int(metadata.get("playtime", 0)),
			"save_size": archive_bytes.size(),
			"cover_size": cover_bytes.size(),
			"created_time": timestamp,
			"modified_time": timestamp,
		},
		"data": archive_bytes,
		"cover": cover_bytes,
	}


func _download_cloud_file(
		uuid: String,
		file_id: String,
		destination_path: String,
		cover: bool,
) -> bool:
	if not _ensure_cloud_save_account():
		return true
	if not _cloud_archives.has(uuid):
		_fail_cloud_save(400002, "指定的云存档不存在")
		return true
	var record: Dictionary = _cloud_archives[uuid]
	if str(record.metadata.file_id) != file_id:
		_fail_cloud_save(400002, "云存档文件 ID 已失效")
		return true
	var bytes: PackedByteArray = record.cover if cover else record.data
	if cover and bytes.is_empty():
		_fail_cloud_save(400002, "云存档没有封面")
		return true
	if not _write_file_atomically(destination_path, bytes):
		_fail_cloud_save(TapTapCloudSaveAdapter.LOCAL_IO_NATIVE_CODE, "无法写入云存档下载文件")
		return true
	if cover:
		cloud_save_cover_downloaded.emit.call_deferred()
	else:
		cloud_save_data_downloaded.emit.call_deferred()
	return true


func _write_file_atomically(destination_path: String, bytes: PackedByteArray) -> bool:
	var parent := destination_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK and not DirAccess.dir_exists_absolute(parent):
		return false
	var temporary_path := destination_path + ".godot-taptap.tmp"
	var backup_path := destination_path + ".godot-taptap.bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(destination_path):
		if DirAccess.rename_absolute(destination_path, backup_path) != OK:
			DirAccess.remove_absolute(temporary_path)
			return false
	if DirAccess.rename_absolute(temporary_path, destination_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, destination_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return true


func _parse_dictionary(raw_json: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw_json)
	return parsed if parsed is Dictionary else {}


func _fail_cloud_save(code: int, message: String) -> void:
	cloud_save_request_failed.emit.call_deferred(code, message)
