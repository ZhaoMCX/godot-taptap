class_name TapTapLoginCommand
extends GFCommand

const TYPE := &"godot_taptap.login.login"

var scopes: PackedStringArray


func _init(requested_scopes: PackedStringArray = PackedStringArray(["public_profile"]), id: String = "") -> void:
	super(id)
	scopes = requested_scopes.duplicate()


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	return {"scopes": Array(scopes)}
