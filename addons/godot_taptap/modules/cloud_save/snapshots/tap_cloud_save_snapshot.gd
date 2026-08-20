class_name TapCloudSaveSnapshot
extends RefCounted

var archives: Array[TapCloudSaveArchiveSnapshot]:
	get:
		return _archives.duplicate()

var busy: bool:
	get:
		return _busy

var pending_kind: StringName:
	get:
		return _pending_kind

var status_code: int:
	get:
		return _status_code

var _archives: Array[TapCloudSaveArchiveSnapshot]
var _busy: bool
var _pending_kind: StringName
var _status_code: int


func _init(
		current_archives: Array[TapCloudSaveArchiveSnapshot],
		is_busy: bool,
		current_pending_kind: StringName,
		current_status_code: int,
) -> void:
	_archives = current_archives.duplicate()
	_busy = is_busy
	_pending_kind = current_pending_kind
	_status_code = current_status_code
