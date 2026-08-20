class_name TapComplianceStartCommand
extends GFCommand

const TYPE := &"godot_taptap.compliance.start"

var open_id: String


func _init(account_open_id: String, id: String = "") -> void:
	super(id)
	open_id = account_open_id


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"open_id": open_id}
