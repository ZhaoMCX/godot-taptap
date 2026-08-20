class_name TapTapCloudSaveModule
extends GFModule

signal archive_created(event: TapCloudSaveArchiveCreatedEvent)
signal archive_updated(event: TapCloudSaveArchiveUpdatedEvent)
signal archive_deleted(event: TapCloudSaveArchiveDeletedEvent)
signal archive_list_received(event: TapCloudSaveArchiveListReceivedEvent)
signal data_downloaded(event: TapCloudSaveDataDownloadedEvent)
signal cover_downloaded(event: TapCloudSaveCoverDownloadedEvent)
signal status_changed(event: TapCloudSaveStatusEvent)
signal command_completed(event: GFCommandCompletedEvent)

var _adapter: TapTapCloudSaveAdapter
var _archives: Array[TapCloudSaveArchiveSnapshot] = []
var _pending_command_id := ""
var _pending_kind: StringName = &""
var _status_code := 0


func configure(adapter: TapTapCloudSaveAdapter) -> void:
	_disconnect_adapter()
	_adapter = adapter
	if _adapter == null:
		return
	_adapter.archive_created.connect(_on_archive_created)
	_adapter.archive_updated.connect(_on_archive_updated)
	_adapter.archive_deleted.connect(_on_archive_deleted)
	_adapter.archive_list_received.connect(_on_archive_list_received)
	_adapter.data_downloaded.connect(_on_data_downloaded)
	_adapter.cover_downloaded.connect(_on_cover_downloaded)
	_adapter.request_failed.connect(_on_request_failed)
	_adapter.status_received.connect(_on_status_received)


func submit_create(command: TapCloudSaveCreateCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"create")
	if validation != null:
		return validation
	validation = _validate_metadata(command.command_id, command.metadata)
	if validation != null:
		return validation
	return _submit(
		command.command_id,
		&"create",
		func() -> TapOperationResult:
			return _adapter.create_archive(command.metadata, command.archive_path, command.cover_path)
	)


func submit_list(command: TapCloudSaveListCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"list")
	if validation != null:
		return validation
	return _submit(command.command_id, &"list", _adapter.list_archives)


func submit_download_data(command: TapCloudSaveDownloadDataCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"download_data")
	if validation != null:
		return validation
	validation = _validate_archive_reference(
		command.command_id, command.uuid, command.file_id, command.destination_path
	)
	if validation != null:
		return validation
	return _submit(
		command.command_id,
		&"download_data",
		func() -> TapOperationResult:
			return _adapter.download_data(command.uuid, command.file_id, command.destination_path)
	)


func submit_update(command: TapCloudSaveUpdateCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"update")
	if validation != null:
		return validation
	validation = _validate_metadata(command.command_id, command.metadata)
	if validation != null:
		return validation
	if command.uuid.is_empty():
		return GFSubmitResult.rejected_result(command.command_id, &"invalid_archive", "云存档 UUID 不能为空")
	return _submit(
		command.command_id,
		&"update",
		func() -> TapOperationResult:
			return _adapter.update_archive(
				command.uuid, command.metadata, command.archive_path, command.cover_path
			)
	)


func submit_delete(command: TapCloudSaveDeleteCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"delete")
	if validation != null:
		return validation
	if command.uuid.is_empty():
		return GFSubmitResult.rejected_result(command.command_id, &"invalid_archive", "云存档 UUID 不能为空")
	return _submit(
		command.command_id,
		&"delete",
		func() -> TapOperationResult: return _adapter.delete_archive(command.uuid)
	)


func submit_download_cover(command: TapCloudSaveDownloadCoverCommand) -> GFSubmitResult:
	var validation := _validate_base(command, &"download_cover")
	if validation != null:
		return validation
	validation = _validate_archive_reference(
		command.command_id, command.uuid, command.file_id, command.destination_path
	)
	if validation != null:
		return validation
	return _submit(
		command.command_id,
		&"download_cover",
		func() -> TapOperationResult:
			return _adapter.download_cover(command.uuid, command.file_id, command.destination_path)
	)


func get_snapshot() -> TapCloudSaveSnapshot:
	return TapCloudSaveSnapshot.new(
		_archives, not _pending_command_id.is_empty(), _pending_kind, _status_code
	)


func _exit_tree() -> void:
	_disconnect_adapter()


func _submit(command_id: String, kind: StringName, operation: Callable) -> GFSubmitResult:
	if _adapter == null:
		return GFSubmitResult.rejected_result(
			command_id, &"not_configured", "TapTap Cloud Save Module 尚未配置"
		)
	_pending_command_id = command_id
	_pending_kind = kind
	var result: TapOperationResult = operation.call()
	if result == null or not result.accepted:
		_clear_pending()
		var error := result.error if result != null else null
		return GFSubmitResult.rejected_result(
			command_id,
			&"native_error" if error == null else _error_code(error),
			"云存档请求未被接受" if error == null else error.message,
		)
	return GFSubmitResult.accepted_result(command_id)


func _validate_base(command: GFCommand, _kind: StringName) -> GFSubmitResult:
	if not GFMessageValidator.is_valid_command(command):
		var command_id := "" if command == null else command.command_id
		return GFSubmitResult.rejected_result(command_id, &"invalid_command", "云存档命令无效")
	if not _pending_command_id.is_empty():
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "云存档操作正在进行")
	return null


func _validate_metadata(command_id: String, metadata: TapCloudSaveMetadata) -> GFSubmitResult:
	if metadata == null:
		return GFSubmitResult.rejected_result(command_id, &"invalid_metadata", "云存档元数据不能为空")
	var name_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]+$")
	if metadata.name.is_empty() or name_pattern.search(metadata.name) == null:
		return GFSubmitResult.rejected_result(
			command_id, &"invalid_archive_name", "存档名只能包含字母、数字、下划线和中划线"
		)
	if metadata.summary.strip_edges().is_empty():
		return GFSubmitResult.rejected_result(command_id, &"invalid_summary", "存档摘要不能为空")
	if metadata.playtime_seconds < 0:
		return GFSubmitResult.rejected_result(command_id, &"invalid_playtime", "游玩时间不能为负数")
	return null


func _validate_archive_reference(
		command_id: String,
		uuid: String,
		file_id: String,
		destination_path: String,
) -> GFSubmitResult:
	if uuid.is_empty() or file_id.is_empty():
		return GFSubmitResult.rejected_result(
			command_id, &"invalid_archive", "云存档 UUID 和文件 ID 不能为空"
		)
	if destination_path.is_empty():
		return GFSubmitResult.rejected_result(command_id, &"invalid_path", "下载目标路径不能为空")
	return null


func _on_archive_created(archive: TapCloudSaveArchiveSnapshot) -> void:
	_upsert_archive(archive)
	var command_id := _take_pending_command_id()
	archive_created.emit(TapCloudSaveArchiveCreatedEvent.new(archive, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_archive_updated(archive: TapCloudSaveArchiveSnapshot) -> void:
	_upsert_archive(archive)
	var command_id := _take_pending_command_id()
	archive_updated.emit(TapCloudSaveArchiveUpdatedEvent.new(archive, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_archive_deleted(archive: TapCloudSaveArchiveSnapshot) -> void:
	_remove_archive(archive.uuid)
	var command_id := _take_pending_command_id()
	archive_deleted.emit(TapCloudSaveArchiveDeletedEvent.new(archive, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_archive_list_received(archives: Array[TapCloudSaveArchiveSnapshot]) -> void:
	_archives = archives.duplicate()
	var command_id := _take_pending_command_id()
	archive_list_received.emit(TapCloudSaveArchiveListReceivedEvent.new(_archives, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_data_downloaded(destination_path: String) -> void:
	var command_id := _take_pending_command_id()
	data_downloaded.emit(TapCloudSaveDataDownloadedEvent.new(destination_path, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_cover_downloaded(destination_path: String) -> void:
	var command_id := _take_pending_command_id()
	cover_downloaded.emit(TapCloudSaveCoverDownloadedEvent.new(destination_path, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_request_failed(error: TapSdkError) -> void:
	var command_id := _take_pending_command_id()
	command_completed.emit(
		GFCommandCompletedEvent.new(command_id, false, _error_code(error), error.message)
	)


func _on_status_received(code: int) -> void:
	_status_code = code
	status_changed.emit(TapCloudSaveStatusEvent.new(code, _pending_command_id))


func _upsert_archive(archive: TapCloudSaveArchiveSnapshot) -> void:
	for index: int in _archives.size():
		if _archives[index].uuid == archive.uuid:
			_archives[index] = archive
			return
	_archives.append(archive)


func _remove_archive(uuid: String) -> void:
	for index: int in range(_archives.size() - 1, -1, -1):
		if _archives[index].uuid == uuid:
			_archives.remove_at(index)


func _take_pending_command_id() -> String:
	var command_id := _pending_command_id
	_clear_pending()
	return command_id


func _clear_pending() -> void:
	_pending_command_id = ""
	_pending_kind = &""


func _disconnect_adapter() -> void:
	if _adapter == null:
		return
	var connections := {
		"archive_created": _on_archive_created,
		"archive_updated": _on_archive_updated,
		"archive_deleted": _on_archive_deleted,
		"archive_list_received": _on_archive_list_received,
		"data_downloaded": _on_data_downloaded,
		"cover_downloaded": _on_cover_downloaded,
		"request_failed": _on_request_failed,
		"status_received": _on_status_received,
	}
	for signal_name: StringName in connections:
		var callback: Callable = connections[signal_name]
		if _adapter.is_connected(signal_name, callback):
			_adapter.disconnect(signal_name, callback)


func _error_code(error: TapSdkError) -> StringName:
	if error == null:
		return &"native_error"
	match error.native_code:
		300001:
			return &"login_required"
		300002:
			return &"sdk_reinitialization_required"
		400000:
			return &"invalid_file_size"
		400001:
			return &"rate_limited"
		400002:
			return &"archive_not_found"
		400003:
			return &"archive_count_limit"
		400004:
			return &"app_storage_limit"
		400005:
			return &"total_storage_limit"
		400006:
			return &"request_timeout"
		400007:
			return &"concurrency_limit"
		400008:
			return &"storage_provider_unavailable"
		400009:
			return &"invalid_archive_name"
	if error.code == TapSdkError.Code.LOCAL_IO_ERROR:
		return &"local_io_error"
	return StringName(TapSdkError.Code.keys()[error.code].to_lower())
