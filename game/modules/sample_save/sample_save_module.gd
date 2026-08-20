class_name SampleSaveModule
extends GFModule

signal slot_loaded(slot_id: String, data: Dictionary)

const SLOT_IDS := ["slot_1", "slot_2", "slot_3"]

@export var save_root := "user://sample_saves"

var _active_slot_id := ""
var _active_data: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_upload_root()))
	_seed_first_slot()


func read_slot(slot_id: String) -> TapCloudSaveLocalSnapshot:
	var data := _read_valid_data(slot_id, _slot_path(slot_id))
	if data.is_empty():
		return TapCloudSaveLocalSnapshot.new()
	return TapCloudSaveLocalSnapshot.new(
		true,
		str(data.get("summary", "示例存档")),
		int(data.get("playtime_seconds", 0)),
		int(data.get("updated_at", 0)),
		FileAccess.get_sha256(_slot_path(slot_id)),
		_cover_path(slot_id) if FileAccess.file_exists(_cover_path(slot_id)) else "",
	)


func prepare_upload(slot_id: String) -> TapCloudSaveUploadPayload:
	var local := read_slot(slot_id)
	if not local.exists:
		return null
	var upload_path := "%s/%s.json" % [_upload_root(), slot_id]
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(_slot_path(slot_id)),
		ProjectSettings.globalize_path(upload_path),
	)
	if copy_error != OK:
		return null
	return TapCloudSaveUploadPayload.new(
		upload_path,
		_cover_path(slot_id) if FileAccess.file_exists(_cover_path(slot_id)) else "",
		local.summary,
		JSON.stringify({"format": "godot_taptap_sample", "version": 1}),
		local.playtime_seconds,
		local.fingerprint,
	)


func import_download(slot_id: String, downloaded_path: String) -> TapCloudSaveLocalResult:
	if not _is_known_slot(slot_id):
		return TapCloudSaveLocalResult.failure(&"invalid_slot", "未知的示例存档槽位")
	if _read_valid_data(slot_id, downloaded_path).is_empty():
		return TapCloudSaveLocalResult.failure(&"invalid_save", "下载文件不是有效的示例存档")
	var target := _slot_path(slot_id)
	var temporary := target + ".import"
	var backup := target + ".bak"
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(downloaded_path),
		ProjectSettings.globalize_path(temporary),
	)
	if copy_error != OK:
		return TapCloudSaveLocalResult.failure(&"local_io_error", "无法暂存下载的存档")
	var target_absolute := ProjectSettings.globalize_path(target)
	var temporary_absolute := ProjectSettings.globalize_path(temporary)
	var backup_absolute := ProjectSettings.globalize_path(backup)
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(target):
		var backup_error := DirAccess.rename_absolute(target_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_absolute)
			return TapCloudSaveLocalResult.failure(&"local_io_error", "无法备份当前本机存档")
	var replace_error := DirAccess.rename_absolute(temporary_absolute, target_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup_absolute, target_absolute)
		return TapCloudSaveLocalResult.failure(&"local_io_error", "无法替换当前本机存档")
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup_absolute)
	return TapCloudSaveLocalResult.success_result()


func load_slot(slot_id: String) -> TapCloudSaveLocalResult:
	var data := _read_valid_data(slot_id, _slot_path(slot_id))
	if data.is_empty():
		return TapCloudSaveLocalResult.failure(&"invalid_save", "本机存档不存在或格式无效")
	_active_slot_id = slot_id
	_active_data = data.duplicate(true)
	slot_loaded.emit(slot_id, _active_data.duplicate(true))
	return TapCloudSaveLocalResult.success_result()


func get_active_slot_id() -> String:
	return _active_slot_id


func get_active_data() -> Dictionary:
	return _active_data.duplicate(true)


func _seed_first_slot() -> void:
	if FileAccess.file_exists(_slot_path("slot_1")):
		return
	var timestamp := int(Time.get_unix_time_from_system())
	var data := {
		"schema_version": 1,
		"slot_id": "slot_1",
		"summary": "序章 · 林间营地",
		"chapter": 1,
		"progress_percent": 12,
		"playtime_seconds": 3720,
		"updated_at": timestamp,
	}
	_write_json(_slot_path("slot_1"), data)
	_create_cover(_cover_path("slot_1"))


func _read_valid_data(slot_id: String, path: String) -> Dictionary:
	if not _is_known_slot(slot_id) or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	if int(parsed.get("schema_version", 0)) != 1 or str(parsed.get("slot_id", "")) != slot_id:
		return {}
	return parsed


func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _create_cover(path: String) -> void:
	if FileAccess.file_exists(path):
		return
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	image.fill(Color("24364b"))
	for y: int in range(220, 360):
		var blend := float(y - 220) / 140.0
		var color := Color("3f8f67").lerp(Color("18291f"), blend)
		for x: int in 640:
			image.set_pixel(x, y, color)
	image.save_png(path)


func _slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [save_root, slot_id]


func _cover_path(slot_id: String) -> String:
	return "%s/%s_cover.png" % [save_root, slot_id]


func _upload_root() -> String:
	return save_root.trim_suffix("/") + "/upload"


func _is_known_slot(slot_id: String) -> bool:
	return slot_id in SLOT_IDS
