class_name GFCommandCompletedEvent
extends GFEvent

const TYPE := &"godot_framework.command_completed"

var succeeded: bool:
	get:
		return _succeeded

var error_code: StringName:
	get:
		return _error_code

var error_message: String:
	get:
		return _error_message

var _succeeded: bool
var _error_code: StringName
var _error_message: String


func _init(
		command_id: String,
		was_successful: bool,
		code: StringName = &"",
		message: String = "",
		event_id: String = "",
) -> void:
	super(command_id, event_id)
	_succeeded = was_successful
	_error_code = &"" if was_successful else code
	_error_message = "" if was_successful else message


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {
		"succeeded": succeeded,
		"error_code": error_code,
		"error_message": error_message,
	}
