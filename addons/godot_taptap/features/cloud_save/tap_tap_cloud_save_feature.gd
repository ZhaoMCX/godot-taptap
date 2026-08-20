class_name TapTapCloudSaveFeature
extends GFFeature

signal state_changed(snapshot: TapTapCloudSaveFeatureSnapshot)
signal slot_loaded(slot_id: String)

const ACTION_LIST := &"list"
const ACTION_UPLOAD := &"upload"
const ACTION_DOWNLOAD := &"download"
const ACTION_DELETE := &"delete"
const ACTION_COVER := &"cover"

var _module: TapTapCloudSaveModule
var _local_store: TapCloudSaveLocalStore
var _sync_store: TapCloudSaveSyncStore
var _active := false
var _cloud_confirmed := false
var _account_key := ""
var _status_message := "等待登录"
var _selected_slot_id := ""
var _slots: Dictionary = {}
var _remote_by_name: Dictionary = {}
var _duplicate_remote_names: Dictionary = {}
var _pending_action: StringName = &""
var _pending_command_id := ""
var _pending_slot_id := ""
var _pending_path := ""
var _pending_upload_fingerprint := ""
var _pending_remote_uuid := ""
var _cover_queue: Array[String] = []
var _queued_user_action: Callable


func configure(
		cloud_save_module: TapTapCloudSaveModule,
		local_store: TapCloudSaveLocalStore,
		sync_store: TapCloudSaveSyncStore = null,
) -> void:
	_disconnect_module()
	_module = cloud_save_module
	_local_store = local_store
	_sync_store = sync_store if sync_store != null else TapCloudSaveSyncStore.new()
	if _module == null:
		return
	_module.archive_created.connect(_on_archive_created)
	_module.archive_updated.connect(_on_archive_updated)
	_module.archive_deleted.connect(_on_archive_deleted)
	_module.archive_list_received.connect(_on_archive_list_received)
	_module.data_downloaded.connect(_on_data_downloaded)
	_module.cover_downloaded.connect(_on_cover_downloaded)
	_module.command_completed.connect(_on_command_completed)


func activate(account_key: String) -> GFSubmitResult:
	if _module == null or _local_store == null or _sync_store == null:
		return _reject(&"not_configured", "云存档界面尚未完成依赖配置")
	if account_key.is_empty():
		return _reject(&"missing_account", "云存档需要有效的 TapTap 账号")
	_account_key = account_key
	_active = true
	_cloud_confirmed = false
	_sync_store.activate(account_key)
	_rebuild_slots()
	_status_message = "正在刷新云存档"
	_emit_state()
	return refresh()


func deactivate() -> void:
	_active = false
	_cloud_confirmed = false
	_account_key = ""
	_slots.clear()
	_remote_by_name.clear()
	_duplicate_remote_names.clear()
	_cover_queue.clear()
	_queued_user_action = Callable()
	_clear_pending()
	_status_message = "等待登录"
	_selected_slot_id = ""
	_emit_state()


func refresh() -> GFSubmitResult:
	if not _active:
		return _reject(&"not_active", "云存档界面尚未激活")
	if not _pending_command_id.is_empty():
		return _reject(&"busy", "云存档操作正在进行")
	_cloud_confirmed = false
	_status_message = "正在刷新云存档"
	var command := TapCloudSaveListCommand.new()
	_set_pending(ACTION_LIST, "", command.command_id)
	_emit_state()
	var result := _module.submit_list(command)
	if not result.accepted:
		_fail_pending(result.error_message)
	return result


func select_slot(slot_id: String) -> void:
	if not _slots.has(slot_id):
		return
	_selected_slot_id = slot_id
	_emit_state()


func request_load(slot_id: String) -> GFSubmitResult:
	return _run_or_queue_user_action(func() -> GFSubmitResult: return _start_load(slot_id))


func request_upload(slot_id: String) -> GFSubmitResult:
	return _run_or_queue_user_action(func() -> GFSubmitResult: return _start_upload(slot_id))


func request_delete(slot_id: String) -> GFSubmitResult:
	return _run_or_queue_user_action(func() -> GFSubmitResult: return _start_delete(slot_id))


func resolve_conflict(slot_id: String, use_cloud: bool) -> GFSubmitResult:
	return request_load(slot_id) if use_cloud else request_upload(slot_id)


func get_snapshot() -> TapTapCloudSaveFeatureSnapshot:
	var snapshots: Array[TapTapCloudSaveSlotSnapshot] = []
	for slot_id: String in _slots:
		snapshots.append(_make_slot_snapshot(slot_id))
	return TapTapCloudSaveFeatureSnapshot.new(
		_active,
		_cloud_confirmed,
		_is_user_busy(),
		_selected_slot_id,
		_status_message,
		snapshots,
	)


func _exit_tree() -> void:
	_disconnect_module()


func _rebuild_slots() -> void:
	_slots.clear()
	var name_pattern := RegEx.create_from_string("^[A-Za-z0-9_-]+$")
	var archive_owners: Dictionary = {}
	for definition: TapCloudSaveSlotDefinition in _local_store.get_slot_definitions():
		if definition == null or definition.slot_id.is_empty():
			continue
		var error := ""
		if _slots.has(definition.slot_id):
			_slots[definition.slot_id].error = "宿主声明了重复的 slot_id"
			continue
		elif name_pattern.search(definition.slot_id) == null:
			error = "slot_id 只能包含字母、数字、下划线和中划线"
		elif definition.archive_name.is_empty() or name_pattern.search(definition.archive_name) == null:
			error = "archive_name 只能包含字母、数字、下划线和中划线"
		elif archive_owners.has(definition.archive_name):
			error = "多个槽位不能使用相同的 archive_name"
			_slots[str(archive_owners[definition.archive_name])].error = error
		else:
			archive_owners[definition.archive_name] = definition.slot_id
		var local := _safe_read_local(definition.slot_id)
		_slots[definition.slot_id] = {
			"definition": definition,
			"local": local,
			"cover_path": local.cover_path,
			"cover_loading": false,
			"definition_error": error,
			"error": error,
		}
	if not _slots.is_empty() and not _slots.has(_selected_slot_id):
		_selected_slot_id = str(_slots.keys()[0])


func _map_remote_archives(archives: Array[TapCloudSaveArchiveSnapshot]) -> void:
	_remote_by_name.clear()
	_duplicate_remote_names.clear()
	var known_names: Dictionary = {}
	for slot_id: String in _slots:
		var definition: TapCloudSaveSlotDefinition = _slots[slot_id].definition
		known_names[definition.archive_name] = true
	for archive: TapCloudSaveArchiveSnapshot in archives:
		if not known_names.has(archive.name):
			push_warning("忽略宿主未声明的 TapTap 云存档：%s" % archive.name)
			continue
		if _remote_by_name.has(archive.name):
			_duplicate_remote_names[archive.name] = true
			continue
		_remote_by_name[archive.name] = archive
	for slot_id: String in _slots:
		_slots[slot_id].local = _safe_read_local(slot_id)
		_slots[slot_id].error = str(_slots[slot_id].definition_error)
		if str(_slots[slot_id].cover_path).is_empty():
			_slots[slot_id].cover_path = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).cover_path
		var definition: TapCloudSaveSlotDefinition = _slots[slot_id].definition
		if _duplicate_remote_names.has(definition.archive_name):
			_slots[slot_id].error = "同一 archive_name 存在多个远端记录，已禁止修改"


func _make_slot_snapshot(slot_id: String) -> TapTapCloudSaveSlotSnapshot:
	var data: Dictionary = _slots[slot_id]
	var definition: TapCloudSaveSlotDefinition = data.definition
	var local: TapCloudSaveLocalSnapshot = data.local
	var remote: TapCloudSaveArchiveSnapshot = _remote_by_name.get(definition.archive_name)
	var error := str(data.error)
	var status := _resolve_status(slot_id, local, remote, error)
	return TapTapCloudSaveSlotSnapshot.new(
		definition,
		local,
		remote,
		status,
		str(data.cover_path),
		bool(data.cover_loading),
		error,
	)


func _resolve_status(
		slot_id: String,
		local: TapCloudSaveLocalSnapshot,
		remote: TapCloudSaveArchiveSnapshot,
		error: String,
) -> TapTapCloudSaveSlotSnapshot.Status:
	if not error.is_empty():
		return TapTapCloudSaveSlotSnapshot.Status.ERROR
	if not _cloud_confirmed:
		return TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED
	if not local.exists and remote == null:
		return TapTapCloudSaveSlotSnapshot.Status.EMPTY
	if local.exists and remote == null:
		return TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY
	if not local.exists:
		return TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY
	var record := _sync_store.get_record(slot_id)
	if record.is_empty():
		return TapTapCloudSaveSlotSnapshot.Status.CONFLICT
	var local_changed := local.fingerprint != str(record.get("local_fingerprint", ""))
	var remote_changed := (
		remote.uuid != str(record.get("remote_uuid", ""))
		or remote.file_id != str(record.get("remote_file_id", ""))
		or remote.modified_time != int(record.get("remote_modified_time", 0))
	)
	if local_changed and remote_changed:
		return TapTapCloudSaveSlotSnapshot.Status.CONFLICT
	if local_changed:
		return TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED
	if remote_changed:
		return TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED
	return TapTapCloudSaveSlotSnapshot.Status.SYNCED


func _start_load(slot_id: String) -> GFSubmitResult:
	var slot := _slot_snapshot_or_null(slot_id)
	if slot == null:
		return _reject(&"invalid_slot", "存档槽位不存在")
	if slot.status == TapTapCloudSaveSlotSnapshot.Status.ERROR:
		return _reject(&"slot_error", slot.error_message)
	if not _cloud_confirmed and slot.local.exists:
		var offline_result := _local_store.load_slot(slot_id)
		if not offline_result.succeeded:
			return _reject(offline_result.error_code, offline_result.error_message)
		_status_message = "%s 已离线载入，云端状态未确认" % slot.definition.display_name
		slot_loaded.emit(slot_id)
		_emit_state()
		return GFSubmitResult.accepted_result(GFId.new_id())
	if slot.remote == null:
		if not slot.local.exists:
			return _reject(&"empty_slot", "当前槽位没有可加载的存档")
		var local_result := _local_store.load_slot(slot_id)
		if not local_result.succeeded:
			return _reject(local_result.error_code, local_result.error_message)
		_status_message = "%s 已载入" % slot.definition.display_name
		slot_loaded.emit(slot_id)
		_emit_state()
		return GFSubmitResult.accepted_result(GFId.new_id())
	if slot.status == TapTapCloudSaveSlotSnapshot.Status.SYNCED and slot.local.exists:
		var cached_result := _local_store.load_slot(slot_id)
		if not cached_result.succeeded:
			return _reject(cached_result.error_code, cached_result.error_message)
		_status_message = "%s 已载入" % slot.definition.display_name
		slot_loaded.emit(slot_id)
		_emit_state()
		return GFSubmitResult.accepted_result(GFId.new_id())
	var path := "%s/%s.download" % [_sync_store.get_account_path(), slot_id]
	var command := TapCloudSaveDownloadDataCommand.new(slot.remote.uuid, slot.remote.file_id, path)
	_set_pending(ACTION_DOWNLOAD, slot_id, command.command_id, path)
	_status_message = "正在下载 %s" % slot.definition.display_name
	_emit_state()
	var result := _module.submit_download_data(command)
	if not result.accepted:
		_fail_pending(result.error_message)
	return result


func _start_upload(slot_id: String) -> GFSubmitResult:
	var slot := _slot_snapshot_or_null(slot_id)
	if slot == null:
		return _reject(&"invalid_slot", "存档槽位不存在")
	if not _cloud_confirmed:
		return _reject(&"cloud_unconfirmed", "云端状态未确认，不能上传")
	if slot.status == TapTapCloudSaveSlotSnapshot.Status.ERROR:
		return _reject(&"slot_error", slot.error_message)
	if not slot.local.exists:
		return _reject(&"empty_local_slot", "当前槽位没有本机存档")
	var payload := _local_store.prepare_upload(slot_id)
	if payload == null or payload.archive_path.is_empty() or payload.summary.strip_edges().is_empty():
		return _reject(&"invalid_upload", "宿主没有提供有效的上传数据")
	var metadata := TapCloudSaveMetadata.new(
		slot.definition.archive_name,
		payload.summary,
		payload.extra,
		payload.playtime_seconds,
	)
	var command: GFCommand
	if slot.remote == null:
		command = TapCloudSaveCreateCommand.new(metadata, payload.archive_path, payload.cover_path)
	else:
		command = TapCloudSaveUpdateCommand.new(
			slot.remote.uuid, metadata, payload.archive_path, payload.cover_path
		)
	_set_pending(ACTION_UPLOAD, slot_id, command.command_id)
	_pending_upload_fingerprint = payload.fingerprint
	_status_message = "正在上传 %s" % slot.definition.display_name
	_emit_state()
	var result := (
		_module.submit_create(command as TapCloudSaveCreateCommand)
		if slot.remote == null
		else _module.submit_update(command as TapCloudSaveUpdateCommand)
	)
	if not result.accepted:
		_fail_pending(result.error_message)
	return result


func _start_delete(slot_id: String) -> GFSubmitResult:
	var slot := _slot_snapshot_or_null(slot_id)
	if slot == null or slot.remote == null:
		return _reject(&"missing_remote", "当前槽位没有云备份")
	if not _cloud_confirmed:
		return _reject(&"cloud_unconfirmed", "云端状态未确认，不能删除")
	if slot.status == TapTapCloudSaveSlotSnapshot.Status.ERROR:
		return _reject(&"slot_error", slot.error_message)
	var command := TapCloudSaveDeleteCommand.new(slot.remote.uuid)
	_set_pending(ACTION_DELETE, slot_id, command.command_id)
	_pending_remote_uuid = slot.remote.uuid
	_status_message = "正在删除 %s 的云备份" % slot.definition.display_name
	_emit_state()
	var result := _module.submit_delete(command)
	if not result.accepted:
		_fail_pending(result.error_message)
	return result


func _on_archive_list_received(event: TapCloudSaveArchiveListReceivedEvent) -> void:
	if _pending_action != ACTION_LIST or event.causation_id != _pending_command_id:
		return
	_clear_pending()
	_cloud_confirmed = true
	_map_remote_archives(event.archives)
	_status_message = "云存档已刷新"
	_prepare_cover_queue()
	_emit_state()
	_pump_cover_queue()


func _on_archive_created(event: TapCloudSaveArchiveCreatedEvent) -> void:
	_complete_upload(event.archive, event.causation_id)


func _on_archive_updated(event: TapCloudSaveArchiveUpdatedEvent) -> void:
	_complete_upload(event.archive, event.causation_id)


func _complete_upload(archive: TapCloudSaveArchiveSnapshot, command_id: String) -> void:
	if _pending_action != ACTION_UPLOAD or command_id != _pending_command_id:
		return
	var slot_id := _pending_slot_id
	var fingerprint := _pending_upload_fingerprint
	_clear_pending()
	_remote_by_name[archive.name] = archive
	_slots[slot_id].local = _safe_read_local(slot_id)
	if str(_slots[slot_id].cover_path).is_empty():
		_slots[slot_id].cover_path = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).cover_path
	if fingerprint.is_empty():
		fingerprint = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).fingerprint
	_write_sync_record(slot_id, archive, fingerprint)
	_status_message = "%s 已上传" % (_slots[slot_id].definition as TapCloudSaveSlotDefinition).display_name
	_emit_state()
	_pump_cover_queue()


func _on_archive_deleted(event: TapCloudSaveArchiveDeletedEvent) -> void:
	if _pending_action != ACTION_DELETE or event.causation_id != _pending_command_id:
		return
	var slot_id := _pending_slot_id
	var remote_uuid := _pending_remote_uuid
	var archive_name := ""
	if _slots.has(slot_id):
		archive_name = (_slots[slot_id].definition as TapCloudSaveSlotDefinition).archive_name
	_clear_pending()
	if event.archive.uuid != remote_uuid:
		push_warning(
			"TapTap 删除响应 UUID 与请求不一致：expected=%s actual=%s"
			% [remote_uuid, event.archive.uuid]
		)
	_remove_remote_archive(archive_name, remote_uuid)
	_sync_store.erase_record(slot_id)
	_slots[slot_id].cover_loading = false
	_slots[slot_id].cover_path = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).cover_path
	_status_message = "云备份已删除，本机存档已保留"
	_emit_state()
	_pump_cover_queue()


func _on_data_downloaded(event: TapCloudSaveDataDownloadedEvent) -> void:
	if _pending_action != ACTION_DOWNLOAD or event.causation_id != _pending_command_id:
		return
	var slot_id := _pending_slot_id
	var slot := _make_slot_snapshot(slot_id)
	_clear_pending()
	var import_result := _local_store.import_download(slot_id, event.destination_path)
	_remove_temporary_file(event.destination_path)
	if not import_result.succeeded:
		_status_message = "导入失败：%s" % import_result.error_message
		_emit_state()
		return
	var load_result := _local_store.load_slot(slot_id)
	if not load_result.succeeded:
		_slots[slot_id].local = _safe_read_local(slot_id)
		_status_message = "存档已下载，但加载失败：%s" % load_result.error_message
		_emit_state()
		return
	_slots[slot_id].local = _safe_read_local(slot_id)
	if str(_slots[slot_id].cover_path).is_empty():
		_slots[slot_id].cover_path = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).cover_path
	_write_sync_record(slot_id, slot.remote, (_slots[slot_id].local as TapCloudSaveLocalSnapshot).fingerprint)
	_status_message = "%s 已从云端载入" % slot.definition.display_name
	slot_loaded.emit(slot_id)
	_emit_state()
	_pump_cover_queue()


func _on_cover_downloaded(event: TapCloudSaveCoverDownloadedEvent) -> void:
	if _pending_action != ACTION_COVER or event.causation_id != _pending_command_id:
		return
	var slot_id := _pending_slot_id
	var path := _pending_path
	_clear_pending()
	if _slots.has(slot_id):
		_slots[slot_id].cover_loading = false
		if FileAccess.file_exists(path):
			_slots[slot_id].cover_path = path
		else:
			_status_message = "封面下载未产生有效文件，存档数据仍可使用"
	_emit_state()
	_after_background_operation()


func _on_command_completed(event: GFCommandCompletedEvent) -> void:
	if event.causation_id != _pending_command_id or event.succeeded:
		return
	var failed_action := _pending_action
	var failed_slot := _pending_slot_id
	_clear_pending()
	if failed_action == ACTION_LIST:
		_cloud_confirmed = false
		_remote_by_name.clear()
		_duplicate_remote_names.clear()
		_status_message = "云端状态未确认：%s" % event.error_message
		_rebuild_slots()
	elif failed_action == ACTION_COVER:
		if _slots.has(failed_slot):
			_slots[failed_slot].cover_loading = false
		_status_message = "封面加载失败，存档数据仍可使用"
	else:
		_status_message = "云存档操作失败：%s" % event.error_message
	_emit_state()
	_after_background_operation()


func _prepare_cover_queue() -> void:
	_cover_queue.clear()
	for slot_id: String in _slots:
		_slots[slot_id].cover_loading = false
		_slots[slot_id].cover_path = (_slots[slot_id].local as TapCloudSaveLocalSnapshot).cover_path
		var slot := _make_slot_snapshot(slot_id)
		if slot.remote == null or slot.remote.cover_size <= 0 or slot.status == TapTapCloudSaveSlotSnapshot.Status.ERROR:
			continue
		var path := _cover_cache_path(slot_id, slot.remote)
		if FileAccess.file_exists(path):
			_slots[slot_id].cover_path = path
		else:
			_cover_queue.append(slot_id)


func _pump_cover_queue() -> void:
	if not _pending_command_id.is_empty() or not _queued_user_action.is_null():
		return
	while not _cover_queue.is_empty():
		var slot_id := _cover_queue.pop_front()
		var slot := _make_slot_snapshot(slot_id)
		if slot.remote == null:
			continue
		var path := _cover_cache_path(slot_id, slot.remote)
		var command := TapCloudSaveDownloadCoverCommand.new(slot.remote.uuid, slot.remote.file_id, path)
		_slots[slot_id].cover_loading = true
		_set_pending(ACTION_COVER, slot_id, command.command_id, path)
		_emit_state()
		var result := _module.submit_download_cover(command)
		if not result.accepted:
			_slots[slot_id].cover_loading = false
			_fail_pending(result.error_message)
			continue
		return


func _run_or_queue_user_action(action: Callable) -> GFSubmitResult:
	if _pending_action == ACTION_COVER:
		if not _queued_user_action.is_null():
			return _reject(&"busy", "已有玩家操作正在等待")
		_queued_user_action = action
		_status_message = "封面下载完成后立即执行操作"
		_emit_state()
		return GFSubmitResult.accepted_result(GFId.new_id())
	if not _pending_command_id.is_empty():
		return _reject(&"busy", "云存档操作正在进行")
	return action.call()


func _after_background_operation() -> void:
	if not _queued_user_action.is_null():
		var action := _queued_user_action
		_queued_user_action = Callable()
		action.call()
		return
	_pump_cover_queue()


func _write_sync_record(
		slot_id: String,
		remote: TapCloudSaveArchiveSnapshot,
		fingerprint: String,
) -> void:
	if remote == null:
		return
	_sync_store.set_record(
		slot_id,
		{
			"local_fingerprint": fingerprint,
			"remote_uuid": remote.uuid,
			"remote_file_id": remote.file_id,
			"remote_modified_time": remote.modified_time,
		},
	)


func _remove_remote_archive(archive_name: String, remote_uuid: String) -> void:
	if _remote_by_name.has(archive_name):
		var named_archive: TapCloudSaveArchiveSnapshot = _remote_by_name[archive_name]
		if named_archive != null and named_archive.uuid == remote_uuid:
			_remote_by_name.erase(archive_name)
	for name: String in _remote_by_name.keys():
		var archive: TapCloudSaveArchiveSnapshot = _remote_by_name[name]
		if archive != null and archive.uuid == remote_uuid:
			_remote_by_name.erase(name)


func _remove_temporary_file(path: String) -> void:
	if path.begins_with("user://") and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cover_cache_path(slot_id: String, remote: TapCloudSaveArchiveSnapshot) -> String:
	return "%s/%s_%s_%d.png" % [
		_sync_store.get_account_path(), slot_id, remote.uuid.sha256_text().left(12), remote.modified_time
	]


func _safe_read_local(slot_id: String) -> TapCloudSaveLocalSnapshot:
	var snapshot := _local_store.read_slot(slot_id)
	return snapshot if snapshot != null else TapCloudSaveLocalSnapshot.new()


func _slot_snapshot_or_null(slot_id: String) -> TapTapCloudSaveSlotSnapshot:
	return _make_slot_snapshot(slot_id) if _slots.has(slot_id) else null


func _set_pending(
		action: StringName,
		slot_id: String,
		command_id: String,
		path: String = "",
) -> void:
	_pending_action = action
	_pending_slot_id = slot_id
	_pending_command_id = command_id
	_pending_path = path


func _clear_pending() -> void:
	_pending_action = &""
	_pending_slot_id = ""
	_pending_command_id = ""
	_pending_path = ""
	_pending_upload_fingerprint = ""
	_pending_remote_uuid = ""


func _fail_pending(message: String) -> void:
	_clear_pending()
	_status_message = message
	_emit_state()


func _is_user_busy() -> bool:
	return (
		_pending_action in [ACTION_LIST, ACTION_UPLOAD, ACTION_DOWNLOAD, ACTION_DELETE]
		or not _queued_user_action.is_null()
	)


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _reject(code: StringName, message: String) -> GFSubmitResult:
	_status_message = message
	_emit_state()
	return GFSubmitResult.rejected_result(GFId.new_id(), code, message)


func _disconnect_module() -> void:
	if _module == null:
		return
	var connections := {
		"archive_created": _on_archive_created,
		"archive_updated": _on_archive_updated,
		"archive_deleted": _on_archive_deleted,
		"archive_list_received": _on_archive_list_received,
		"data_downloaded": _on_data_downloaded,
		"cover_downloaded": _on_cover_downloaded,
		"command_completed": _on_command_completed,
	}
	for signal_name: StringName in connections:
		var callback: Callable = connections[signal_name]
		if _module.is_connected(signal_name, callback):
			_module.disconnect(signal_name, callback)
