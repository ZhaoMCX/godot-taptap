class_name TapTapLoginSnapshot
extends RefCounted

var account: TapTapAccountSnapshot:
	get:
		return _account

var busy: bool:
	get:
		return _busy

var _account: TapTapAccountSnapshot
var _busy: bool


func _init(current_account: TapTapAccountSnapshot, is_busy: bool) -> void:
	_account = current_account
	_busy = is_busy
