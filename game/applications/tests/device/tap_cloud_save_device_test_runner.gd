class_name TapCloudSaveDeviceTestRunner
extends Node

enum Step {
	IDLE,
	BASELINE_LIST,
	DELETE_STALE,
	REFRESH_AFTER_STALE,
	CREATE,
	VERIFY_CREATE_LIST,
	PREPARE_DOWNLOAD_V1,
	DOWNLOAD_V1,
	UPDATE,
	VERIFY_UPDATE_LIST,
	RESTART_VERIFY_LIST,
	PREPARE_DOWNLOAD_V2,
	DOWNLOAD_V2,
	DELETE,
	VERIFY_DELETE_LIST,
	RECREATE,
	CLEANUP_DELETE,
	CLEANUP_FAILURE,
	FINISHED,
}

const TEST_DIRECTORY := "user://cloud_save_device_test"
const RESTART_STATE_PATH := TEST_DIRECTORY + "/restart_state.json"
const OPERATION_TIMEOUT_SECONDS := 45.0

var _feature: TapTapCloudSaveFeature
var _local_store: TapCloudSaveDeviceLocalStore
var _step := Step.IDLE
var _original_uuid := ""
var _failure_message := ""
var _timeout: Timer
var _submitting := false


func configure(
		feature: TapTapCloudSaveFeature,
		local_store: TapCloudSaveDeviceLocalStore,
) -> void:
	_feature = feature
	_local_store = local_store
	_feature.state_changed.connect(_on_state_changed)
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.timeout.connect(_on_timeout)
	add_child(_timeout)


func start(_account: TapTapAccountSnapshot = null) -> void:
	if _step != Step.IDLE:
		return
	if FileAccess.file_exists(RESTART_STATE_PATH):
		var state := _read_json(RESTART_STATE_PATH)
		_original_uuid = str(state.get("archive_uuid", ""))
		if _original_uuid.is_empty():
			_finish(false, "跨进程状态缺少 archive_uuid")
			return
		_log("resumed", {"archive_name": _local_store.archive_name, "uuid": _original_uuid})
		_step = Step.RESTART_VERIFY_LIST
	else:
		_log("started", {"archive_name": _local_store.archive_name})
		_step = Step.BASELINE_LIST
	_arm_timeout()
	_observe(_feature.get_snapshot())


func _on_state_changed(snapshot: TapTapCloudSaveFeatureSnapshot) -> void:
	_observe(snapshot)


func _observe(snapshot: TapTapCloudSaveFeatureSnapshot) -> void:
	if _submitting or _step in [Step.IDLE, Step.FINISHED] or snapshot.busy or not snapshot.cloud_confirmed:
		return
	var slot := _slot(snapshot)
	if slot == null:
		_fail("Feature 快照缺少 device_test 槽位")
		return
	match _step:
		Step.BASELINE_LIST:
			if slot.remote != null:
				_submit(Step.DELETE_STALE, _feature.request_delete.bind(slot.definition.slot_id))
			else:
				_start_create()
		Step.DELETE_STALE:
			if slot.remote != null:
				_fail("清理遗留远端存档后缓存仍未清除")
				return
			_submit(Step.REFRESH_AFTER_STALE, _feature.refresh)
		Step.REFRESH_AFTER_STALE:
			if slot.remote != null:
				_fail("刷新后遗留远端存档仍然存在")
				return
			_start_create()
		Step.CREATE:
			if slot.remote == null:
				_fail("创建成功后 Feature 未保存远端快照")
				return
			_original_uuid = slot.remote.uuid
			_submit(Step.VERIFY_CREATE_LIST, _feature.refresh)
		Step.VERIFY_CREATE_LIST:
			if not _verify_remote(slot, 1, _original_uuid):
				return
			_local_store.remove_local()
			_submit(Step.PREPARE_DOWNLOAD_V1, _feature.refresh)
		Step.PREPARE_DOWNLOAD_V1:
			if slot.status != TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY:
				_fail("删除本机副本后槽位不是 CLOUD_ONLY")
				return
			_submit(Step.DOWNLOAD_V1, _feature.request_load.bind(slot.definition.slot_id))
		Step.DOWNLOAD_V1:
			if _local_store.loaded_version != 1 or _local_store.get_version() != 1:
				_fail("V1 云端下载、导入或加载结果不正确")
				return
			if not _local_store.write_version(2):
				_fail("无法准备 V2 本机存档")
				return
			_submit(Step.UPDATE, _feature.request_upload.bind(slot.definition.slot_id))
		Step.UPDATE:
			if slot.remote == null or slot.remote.uuid != _original_uuid:
				_fail("更新操作意外创建了不同 UUID")
				return
			_submit(Step.VERIFY_UPDATE_LIST, _feature.refresh)
		Step.VERIFY_UPDATE_LIST:
			if not _verify_remote(slot, 2, _original_uuid):
				return
			if not _write_json(RESTART_STATE_PATH, {"archive_uuid": _original_uuid}):
				_fail("无法保存跨进程测试状态")
				return
			_timeout.stop()
			_log("restart_required", {"archive_name": _local_store.archive_name, "uuid": _original_uuid})
			get_tree().quit(0)
		Step.RESTART_VERIFY_LIST:
			if not _verify_remote(slot, 2, _original_uuid):
				return
			_local_store.remove_local()
			_submit(Step.PREPARE_DOWNLOAD_V2, _feature.refresh)
		Step.PREPARE_DOWNLOAD_V2:
			if slot.status != TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY:
				_fail("重启后删除本机副本，槽位不是 CLOUD_ONLY")
				return
			_submit(Step.DOWNLOAD_V2, _feature.request_load.bind(slot.definition.slot_id))
		Step.DOWNLOAD_V2:
			if _local_store.loaded_version != 2 or _local_store.get_version() != 2:
				_fail("重启后的 V2 下载、导入或加载结果不正确")
				return
			_submit(Step.DELETE, _feature.request_delete.bind(slot.definition.slot_id))
		Step.DELETE:
			if slot.remote != null or slot.status != TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY:
				_fail("UUID-only 删除响应后 Feature 仍保留旧远端状态")
				return
			_submit(Step.VERIFY_DELETE_LIST, _feature.refresh)
		Step.VERIFY_DELETE_LIST:
			if slot.remote != null:
				_fail("删除后刷新仍返回旧远端存档")
				return
			_submit(Step.RECREATE, _feature.request_upload.bind(slot.definition.slot_id))
		Step.RECREATE:
			if slot.remote == null or slot.remote.uuid.is_empty():
				_fail("删除后的重新上传没有创建远端存档")
				return
			if slot.remote.uuid == _original_uuid:
				_fail("删除后的重新上传仍使用旧 UUID")
				return
			_log("recreated", {"old_uuid": _original_uuid, "new_uuid": slot.remote.uuid})
			_submit(Step.CLEANUP_DELETE, _feature.request_delete.bind(slot.definition.slot_id))
		Step.CLEANUP_DELETE:
			if slot.remote != null:
				_fail("最终清理后仍保留远端存档")
				return
			_finish(true, "Feature/Application 云存档创建、下载、更新、重启、删除和重建闭环通过")
		Step.CLEANUP_FAILURE:
			_finish(false, _failure_message + "；远端测试存档已清理")


func _start_create() -> void:
	if not _local_store.write_version(1):
		_fail("无法准备 V1 本机存档")
		return
	var slot := _slot(_feature.get_snapshot())
	if slot == null:
		_fail("创建前缺少 device_test 槽位")
		return
	_submit(Step.CREATE, _feature.request_upload.bind(slot.definition.slot_id))


func _submit(next_step: Step, action: Callable) -> void:
	_step = next_step
	_arm_timeout()
	_submitting = true
	var result: GFSubmitResult = action.call()
	_submitting = false
	if not result.accepted:
		call_deferred("_fail", "步骤 %s 未提交：%s %s" % [
			Step.keys()[next_step], result.error_code, result.error_message
		])
	else:
		_log("submitted", {"step": Step.keys()[next_step], "command_id": result.command_id})
		call_deferred("_observe", _feature.get_snapshot())


func _verify_remote(slot: TapTapCloudSaveSlotSnapshot, version: int, expected_uuid: String) -> bool:
	if slot.remote == null:
		_fail("远端列表缺少测试存档")
		return false
	if slot.remote.uuid != expected_uuid:
		_fail("远端 UUID 与预期不一致")
		return false
	if slot.remote.summary != "device-v%d" % version:
		_fail("远端摘要不是 V%d" % version)
		return false
	return true


func _slot(snapshot: TapTapCloudSaveFeatureSnapshot) -> TapTapCloudSaveSlotSnapshot:
	for slot: TapTapCloudSaveSlotSnapshot in snapshot.slots:
		if slot.definition.slot_id == TapCloudSaveDeviceLocalStore.SLOT_ID:
			return slot
	return null


func _fail(message: String) -> void:
	if _step == Step.FINISHED:
		return
	_timeout.stop()
	_failure_message = message
	_log("failure", {"step": Step.keys()[_step], "message": message})
	var slot := _slot(_feature.get_snapshot())
	if _step != Step.CLEANUP_FAILURE and slot != null and slot.remote != null:
		_submit(Step.CLEANUP_FAILURE, _feature.request_delete.bind(slot.definition.slot_id))
		return
	_finish(false, message)


func _finish(succeeded: bool, message: String) -> void:
	_step = Step.FINISHED
	_timeout.stop()
	_log("passed" if succeeded else "failed", {"message": message})
	if succeeded:
		_remove_tree(TEST_DIRECTORY)
	get_tree().quit(0 if succeeded else 1)


func _arm_timeout() -> void:
	_timeout.start(OPERATION_TIMEOUT_SECONDS)


func _on_timeout() -> void:
	_fail("步骤 %s 超过 %.0f 秒未完成" % [Step.keys()[_step], OPERATION_TIMEOUT_SECONDS])


func _write_json(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.close()
	return true


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _remove_tree(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)


func _log(event: String, data: Dictionary) -> void:
	print("CLOUD_SAVE_DEVICE_TEST|%s|%s" % [event, JSON.stringify(data)])
