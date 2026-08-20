class_name TapSdkStateSnapshot
extends RefCounted

var state: int:
	get:
		return _state

var error_message: String:
	get:
		return _error_message

var _state: int
var _error_message: String


func _init(current_state: int, current_error_message: String = "") -> void:
	_state = current_state
	_error_message = current_error_message
