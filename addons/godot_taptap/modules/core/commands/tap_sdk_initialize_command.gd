class_name TapSdkInitializeCommand
extends GFCommand

const TYPE := &"godot_taptap.core.initialize"

var privacy_policy_accepted: bool


func _init(privacy_accepted: bool, id: String = "") -> void:
	super(id)
	privacy_policy_accepted = privacy_accepted


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"privacy_policy_accepted": privacy_policy_accepted}
