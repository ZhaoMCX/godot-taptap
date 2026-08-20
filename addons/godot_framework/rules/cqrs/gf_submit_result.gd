class_name GFSubmitResult
extends RefCounted

var accepted: bool:
	get:
		return _accepted

var command_id: String:
	get:
		return _command_id

var error_code: StringName:
	get:
		return _error_code

var error_message: String:
	get:
		return _error_message

var _accepted: bool
var _command_id: String
var _error_code: StringName
var _error_message: String


func _init(
		is_accepted: bool,
		id: String,
		code: StringName = &"",
		message: String = "",
) -> void:
	_accepted = is_accepted
	_command_id = id
	_error_code = &"" if is_accepted else code
	_error_message = "" if is_accepted else message


static func accepted_result(command_id: String) -> GFSubmitResult:
	return GFSubmitResult.new(true, command_id)


static func rejected_result(
		command_id: String,
		code: StringName,
		message: String = "",
) -> GFSubmitResult:
	return GFSubmitResult.new(false, command_id, code, message)
