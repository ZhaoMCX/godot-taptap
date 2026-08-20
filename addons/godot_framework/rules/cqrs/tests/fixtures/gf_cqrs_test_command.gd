class_name GFCqrsTestCommand
extends GFCommand

const DEFAULT_TYPE := &"tests.cqrs.command"

var message_type: StringName
var payload: Dictionary


func _init(
		id: String = "",
		type: StringName = DEFAULT_TYPE,
		data: Dictionary = {},
) -> void:
	super(id)
	message_type = type
	payload = data.duplicate(true)


func get_message_type() -> StringName:
	return message_type


func to_payload() -> Dictionary:
	return payload.duplicate(true)
