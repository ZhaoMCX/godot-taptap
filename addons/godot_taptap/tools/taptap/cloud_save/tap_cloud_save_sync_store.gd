class_name TapCloudSaveSyncStore
extends RefCounted

const DEFAULT_ROOT := "user://godot_taptap/cloud_save"

var _root_path: String
var _account_path := ""
var _records: Dictionary = {}


func _init(root_path: String = DEFAULT_ROOT) -> void:
	_root_path = root_path.trim_suffix("/")


func activate(account_key: String) -> void:
	_records.clear()
	_account_path = ""
	if account_key.is_empty():
		return
	var account_hash := account_key.sha256_text()
	_account_path = "%s/%s" % [_root_path, account_hash]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_account_path))
	_load()


func get_account_path() -> String:
	return _account_path


func get_record(slot_id: String) -> Dictionary:
	var value: Variant = _records.get(slot_id, {})
	return value.duplicate(true) if value is Dictionary else {}


func set_record(slot_id: String, record: Dictionary) -> bool:
	if _account_path.is_empty() or slot_id.is_empty():
		return false
	var candidate := _records.duplicate(true)
	candidate[slot_id] = record.duplicate(true)
	if not _save(candidate):
		return false
	_records = candidate
	return true


func erase_record(slot_id: String) -> bool:
	if _account_path.is_empty():
		return false
	var candidate := _records.duplicate(true)
	candidate.erase(slot_id)
	if not _save(candidate):
		return false
	_records = candidate
	return true


func _load() -> void:
	var path := _account_path + "/sync_state.json"
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		_records = parsed.duplicate(true)


func _save(records: Dictionary) -> bool:
	var path := _account_path + "/sync_state.json"
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	return _replace_file(path, temporary_path)


func _replace_file(path: String, temporary_path: String) -> bool:
	var backup_path := path + ".bak"
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(absolute_path, absolute_backup) != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return false
	if DirAccess.rename_absolute(absolute_temporary, absolute_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true
