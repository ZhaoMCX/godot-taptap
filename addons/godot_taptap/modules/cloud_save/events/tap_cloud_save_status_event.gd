class_name TapCloudSaveStatusEvent
extends GFEvent

enum Category {
	LOGIN_REQUIRED,
	REINITIALIZATION_REQUIRED,
	UNKNOWN,
}

const TYPE := &"godot_taptap.cloud_save.status"
const LOGIN_REQUIRED_CODE := 300001
const REINITIALIZATION_REQUIRED_CODE := 300002

var code: int
var category: Category


func _init(status_code: int, command_id: String = "", event_id: String = "") -> void:
	super(command_id, event_id)
	code = status_code
	match code:
		LOGIN_REQUIRED_CODE:
			category = Category.LOGIN_REQUIRED
		REINITIALIZATION_REQUIRED_CODE:
			category = Category.REINITIALIZATION_REQUIRED
		_:
			category = Category.UNKNOWN


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"code": code, "category": Category.keys()[category].to_lower()}
