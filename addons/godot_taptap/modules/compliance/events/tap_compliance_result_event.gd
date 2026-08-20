class_name TapComplianceResultEvent
extends GFEvent

const TYPE := &"godot_taptap.compliance.result"

var result: TapComplianceResult


func _init(compliance_result: TapComplianceResult, command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)
	result = compliance_result


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {
		"code": result.code,
		"category": result.category,
		"metadata": result.metadata.duplicate(true),
	}
