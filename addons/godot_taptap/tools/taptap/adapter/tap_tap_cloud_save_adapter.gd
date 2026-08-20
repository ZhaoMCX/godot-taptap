class_name TapTapCloudSaveAdapter
extends RefCounted

signal archive_created(archive: TapCloudSaveArchiveSnapshot)
signal archive_updated(archive: TapCloudSaveArchiveSnapshot)
signal archive_deleted(archive: TapCloudSaveArchiveSnapshot)
signal archive_list_received(archives: Array[TapCloudSaveArchiveSnapshot])
signal data_downloaded(destination_path: String)
signal cover_downloaded(destination_path: String)
signal request_failed(error: TapSdkError)
signal status_received(code: int)

const MAX_ARCHIVE_BYTES := 10 * 1024 * 1024
const MAX_COVER_BYTES := 512 * 1024
const LOCAL_IO_NATIVE_CODE := -1000

var _bridge: Object
var _core: TapSdkCoreAdapter
var _operation_in_progress := false
var _pending_operation: StringName = &""
var _pending_destination := ""


func _init(bridge: Object, core_adapter: TapSdkCoreAdapter) -> void:
	_bridge = bridge
	_core = core_adapter
	if _bridge == null:
		return
	_connect_bridge_signal(&"cloud_save_archive_created", _on_archive_created)
	_connect_bridge_signal(&"cloud_save_archive_updated", _on_archive_updated)
	_connect_bridge_signal(&"cloud_save_archive_deleted", _on_archive_deleted)
	_connect_bridge_signal(&"cloud_save_archive_list_received", _on_archive_list_received)
	_connect_bridge_signal(&"cloud_save_data_downloaded", _on_data_downloaded)
	_connect_bridge_signal(&"cloud_save_cover_downloaded", _on_cover_downloaded)
	_connect_bridge_signal(&"cloud_save_request_failed", _on_request_failed)
	_connect_bridge_signal(&"cloud_save_status", _on_status_received)


func create_archive(
		metadata: TapCloudSaveMetadata,
		archive_path: String,
		cover_path: String = "",
) -> TapOperationResult:
	var validation := _validate_ready_and_idle()
	if validation != null:
		return TapOperationResult.rejected(validation)
	if metadata == null:
		return _reject(TapSdkError.Code.INVALID_CONFIG, "云存档元数据不能为空")
	validation = _validate_upload_path(archive_path, MAX_ARCHIVE_BYTES, "存档")
	if validation != null:
		return TapOperationResult.rejected(validation)
	if not cover_path.is_empty():
		validation = _validate_upload_path(cover_path, MAX_COVER_BYTES, "封面")
		if validation != null:
			return TapOperationResult.rejected(validation)
	return _start_request(
		&"cloud_save_create",
		[
			JSON.stringify(metadata.to_dictionary()),
			_resolve_user_path(archive_path),
			"" if cover_path.is_empty() else _resolve_user_path(cover_path),
		],
	)


func list_archives() -> TapOperationResult:
	var validation := _validate_ready_and_idle()
	if validation != null:
		return TapOperationResult.rejected(validation)
	return _start_request(&"cloud_save_list", [])


func download_data(uuid: String, file_id: String, destination_path: String) -> TapOperationResult:
	return _start_download(&"cloud_save_download_data", uuid, file_id, destination_path)


func update_archive(
		uuid: String,
		metadata: TapCloudSaveMetadata,
		archive_path: String,
		cover_path: String = "",
) -> TapOperationResult:
	var validation := _validate_ready_and_idle()
	if validation != null:
		return TapOperationResult.rejected(validation)
	if uuid.is_empty() or metadata == null:
		return _reject(TapSdkError.Code.INVALID_CONFIG, "云存档 UUID 和元数据不能为空")
	validation = _validate_upload_path(archive_path, MAX_ARCHIVE_BYTES, "存档")
	if validation != null:
		return TapOperationResult.rejected(validation)
	if not cover_path.is_empty():
		validation = _validate_upload_path(cover_path, MAX_COVER_BYTES, "封面")
		if validation != null:
			return TapOperationResult.rejected(validation)
	return _start_request(
		&"cloud_save_update",
		[
			uuid,
			JSON.stringify(metadata.to_dictionary()),
			_resolve_user_path(archive_path),
			"" if cover_path.is_empty() else _resolve_user_path(cover_path),
		],
	)


func delete_archive(uuid: String) -> TapOperationResult:
	var validation := _validate_ready_and_idle()
	if validation != null:
		return TapOperationResult.rejected(validation)
	if uuid.is_empty():
		return _reject(TapSdkError.Code.INVALID_CONFIG, "云存档 UUID 不能为空")
	return _start_request(&"cloud_save_delete", [uuid])


func download_cover(uuid: String, file_id: String, destination_path: String) -> TapOperationResult:
	return _start_download(&"cloud_save_download_cover", uuid, file_id, destination_path)


func is_ready() -> bool:
	return _validate_ready() == null


func _start_download(
		method: StringName,
		uuid: String,
		file_id: String,
		destination_path: String,
) -> TapOperationResult:
	var validation := _validate_ready_and_idle()
	if validation != null:
		return TapOperationResult.rejected(validation)
	if uuid.is_empty() or file_id.is_empty():
		return _reject(TapSdkError.Code.INVALID_CONFIG, "云存档 UUID 和文件 ID 不能为空")
	validation = _validate_destination_path(destination_path)
	if validation != null:
		return TapOperationResult.rejected(validation)
	_pending_destination = destination_path
	var result := _start_request(
		method, [uuid, file_id, _resolve_user_path(destination_path)]
	)
	if not result.accepted:
		_pending_destination = ""
	return result


func _start_request(method: StringName, arguments: Array) -> TapOperationResult:
	_operation_in_progress = true
	_pending_operation = method
	var accepted := bool(_bridge.callv(method, arguments))
	if not accepted:
		_complete_operation()
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝云存档请求")
	return TapOperationResult.accepted_result()


func _validate_ready_and_idle() -> TapSdkError:
	var ready_error := _validate_ready()
	if ready_error != null:
		return ready_error
	if _operation_in_progress:
		return TapSdkError.create(TapSdkError.Code.BUSY, "云存档请求正在进行")
	return null


func _validate_ready() -> TapSdkError:
	if _bridge == null:
		return TapSdkError.create(TapSdkError.Code.UNAVAILABLE, "当前平台没有可用的 TapSDK 原生桥接")
	if _core == null or not _core.is_initialized():
		return TapSdkError.create(TapSdkError.Code.NOT_INITIALIZED, "TapSDK 尚未初始化")
	return null


func _validate_upload_path(path: String, maximum_size: int, label: String) -> TapSdkError:
	var path_error := _validate_user_path(path)
	if path_error != null:
		return path_error
	if not FileAccess.file_exists(path):
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "%s文件不存在：%s" % [label, path])
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return TapSdkError.create(TapSdkError.Code.LOCAL_IO_ERROR, "无法读取%s文件：%s" % [label, path])
	var length := file.get_length()
	if length > maximum_size:
		return TapSdkError.create(
			TapSdkError.Code.INVALID_CONFIG,
			"%s文件超过大小限制：%d > %d" % [label, length, maximum_size],
		)
	return null


func _validate_destination_path(path: String) -> TapSdkError:
	var path_error := _validate_user_path(path)
	if path_error != null:
		return path_error
	if path.ends_with("/") or path.get_file().is_empty():
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "下载目标必须是文件路径")
	return null


func _validate_user_path(path: String) -> TapSdkError:
	if not path.begins_with("user://"):
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "云存档文件路径必须位于 user://")
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().trim_suffix("/")
	var resolved := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	if resolved != user_root and not resolved.begins_with(user_root + "/"):
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "云存档文件路径越过 user:// 边界")
	return null


func _resolve_user_path(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()


func _connect_bridge_signal(signal_name: StringName, callback: Callable) -> void:
	if _bridge.has_signal(signal_name) and not _bridge.is_connected(signal_name, callback):
		_bridge.connect(signal_name, callback)


func _on_archive_created(raw_json: String) -> void:
	if not _accept_response(&"cloud_save_create"):
		return
	var archive := _parse_archive(raw_json)
	if archive == null:
		_fail_invalid_response("创建云存档返回格式无效")
		return
	_complete_operation()
	archive_created.emit(archive)


func _on_archive_updated(raw_json: String) -> void:
	if not _accept_response(&"cloud_save_update"):
		return
	var archive := _parse_archive(raw_json)
	if archive == null:
		_fail_invalid_response("更新云存档返回格式无效")
		return
	_complete_operation()
	archive_updated.emit(archive)


func _on_archive_deleted(raw_json: String) -> void:
	if not _accept_response(&"cloud_save_delete"):
		return
	var archive := _parse_archive(raw_json)
	if archive == null:
		_fail_invalid_response("删除云存档返回格式无效")
		return
	_complete_operation()
	archive_deleted.emit(archive)


func _on_archive_list_received(raw_json: String) -> void:
	if not _accept_response(&"cloud_save_list"):
		return
	var parsed: Variant = JSON.parse_string(raw_json)
	if not parsed is Array:
		_fail_invalid_response("云存档列表返回格式无效")
		return
	var archives: Array[TapCloudSaveArchiveSnapshot] = []
	for item: Variant in parsed:
		if not item is Dictionary:
			_fail_invalid_response("云存档列表包含无效条目")
			return
		archives.append(TapCloudSaveArchiveSnapshot.from_dictionary(item))
	_complete_operation()
	archive_list_received.emit(archives)


func _on_data_downloaded() -> void:
	if not _accept_response(&"cloud_save_download_data"):
		return
	var destination := _pending_destination
	_complete_operation()
	data_downloaded.emit(destination)


func _on_cover_downloaded() -> void:
	if not _accept_response(&"cloud_save_download_cover"):
		return
	var destination := _pending_destination
	_complete_operation()
	cover_downloaded.emit(destination)


func _on_request_failed(native_code: int, message: String) -> void:
	if not _operation_in_progress:
		push_warning("忽略没有对应请求的 TapTap 云存档失败回调")
		return
	_complete_operation()
	var code := TapSdkError.Code.LOCAL_IO_ERROR if native_code == LOCAL_IO_NATIVE_CODE else TapSdkError.Code.NATIVE_ERROR
	request_failed.emit(TapSdkError.create(code, message, native_code))


func _on_status_received(code: int) -> void:
	status_received.emit(code)


func _parse_archive(raw_json: String) -> TapCloudSaveArchiveSnapshot:
	var parsed: Variant = JSON.parse_string(raw_json)
	if parsed is Dictionary and not str(parsed.get("uuid", "")).is_empty():
		return TapCloudSaveArchiveSnapshot.from_dictionary(parsed)
	return null


func _fail_invalid_response(message: String) -> void:
	_complete_operation()
	request_failed.emit(TapSdkError.create(TapSdkError.Code.INVALID_RESPONSE, message))


func _accept_response(expected_operation: StringName) -> bool:
	if not _operation_in_progress:
		push_warning("忽略没有对应请求的 TapTap 云存档回调：%s" % expected_operation)
		return false
	if _pending_operation != expected_operation:
		push_warning(
			"忽略与当前请求不匹配的 TapTap 云存档回调：expected=%s actual=%s"
			% [_pending_operation, expected_operation]
		)
		return false
	return true


func _complete_operation() -> void:
	_operation_in_progress = false
	_pending_operation = &""
	_pending_destination = ""


func _reject(code: TapSdkError.Code, message: String) -> TapOperationResult:
	return TapOperationResult.rejected(TapSdkError.create(code, message))
