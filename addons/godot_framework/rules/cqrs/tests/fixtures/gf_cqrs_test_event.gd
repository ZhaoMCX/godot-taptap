class_name GFCqrsTestEvent
extends GFEvent

const DEFAULT_TYPE := &"tests.cqrs.event"

var message_type: StringName
var payload: Dictionary


func _init(
		caused_by: String = "",
		id: String = "",
		type: StringName = DEFAULT_TYPE,
		data: Dictionary = {},
) -> void:
	super(caused_by, id)
	message_type = type
	payload = data.duplicate(true)


func get_message_type() -> StringName:
	return message_type


func to_payload() -> Dictionary:
	return payload.duplicate(true)
