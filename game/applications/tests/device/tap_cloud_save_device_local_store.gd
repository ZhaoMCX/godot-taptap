class_name TapCloudSaveDeviceLocalStore
extends TapCloudSaveLocalStore

const SLOT_ID := "device_test"
const TEST_DIRECTORY := "user://cloud_save_device_test"
const ARCHIVE_NAME_PATH := TEST_DIRECTORY + "/archive_name.txt"
const SAVE_PATH := TEST_DIRECTORY + "/local_save.json"

var archive_name := ""
var loaded_version := 0


func prepare_for_launch() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY)) != OK:
		return false
	if FileAccess.file_exists(ARCHIVE_NAME_PATH):
		archive_name = FileAccess.get_file_as_string(ARCHIVE_NAME_PATH).strip_edges()
	if archive_name.is_empty():
		archive_name = "gf_device_%d" % int(Time.get_unix_time_from_system())
		var file := FileAccess.open(ARCHIVE_NAME_PATH, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(archive_name)
		file.close()
	return true


func write_version(version: int) -> bool:
	return _write_save(SAVE_PATH, {
		"schema_version": 1,
		"slot_id": SLOT_ID,
		"version": version,
		"summary": "device-v%d" % version,
		"playtime_seconds": version * 100,
		"updated_at": int(Time.get_unix_time_from_system()),
	})


func remove_local() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func get_version() -> int:
	return int(_read_save(SAVE_PATH).get("version", 0))


func get_slot_definitions() -> Array[TapCloudSaveSlotDefinition]:
	return [TapCloudSaveSlotDefinition.new(SLOT_ID, archive_name, "真机测试存档")]


func read_slot(slot_id: String) -> TapCloudSaveLocalSnapshot:
	var data := _read_save(SAVE_PATH) if slot_id == SLOT_ID else {}
	if data.is_empty():
		return TapCloudSaveLocalSnapshot.new()
	return TapCloudSaveLocalSnapshot.new(
		true,
		str(data.summary),
		int(data.playtime_seconds),
		int(data.updated_at),
		FileAccess.get_sha256(SAVE_PATH),
	)


func prepare_upload(slot_id: String) -> TapCloudSaveUploadPayload:
	var local := read_slot(slot_id)
	if not local.exists:
		return null
	return TapCloudSaveUploadPayload.new(
		SAVE_PATH,
		"",
		local.summary,
		JSON.stringify({"device_test": true, "version": get_version()}),
		local.playtime_seconds,
		local.fingerprint,
	)


func import_download(slot_id: String, downloaded_path: String) -> TapCloudSaveLocalResult:
	if slot_id != SLOT_ID or _read_save(downloaded_path).is_empty():
		return TapCloudSaveLocalResult.failure(&"invalid_save", "下载内容不是有效的真机测试存档")
	var temporary := SAVE_PATH + ".import"
	if DirAccess.copy_absolute(
			ProjectSettings.globalize_path(downloaded_path),
			ProjectSettings.globalize_path(temporary),
	) != OK:
		return TapCloudSaveLocalResult.failure(&"local_io_error", "无法暂存下载存档")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(SAVE_PATH),
	) != OK:
		return TapCloudSaveLocalResult.failure(&"local_io_error", "无法替换本机测试存档")
	return TapCloudSaveLocalResult.success_result()


func load_slot(slot_id: String) -> TapCloudSaveLocalResult:
	var data := _read_save(SAVE_PATH) if slot_id == SLOT_ID else {}
	if data.is_empty():
		return TapCloudSaveLocalResult.failure(&"invalid_save", "本机测试存档无效")
	loaded_version = int(data.version)
	return TapCloudSaveLocalResult.success_result()


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	if int(parsed.get("schema_version", 0)) != 1 or str(parsed.get("slot_id", "")) != SLOT_ID:
		return {}
	return parsed


func _write_save(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true
