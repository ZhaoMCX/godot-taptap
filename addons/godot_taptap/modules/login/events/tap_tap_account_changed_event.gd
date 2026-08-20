class_name TapTapAccountChangedEvent
extends GFEvent

const TYPE := &"godot_taptap.login.account_changed"

var account: TapTapAccountSnapshot


func _init(current_account: TapTapAccountSnapshot, command_id: String, event_id: String = "") -> void:
	super(command_id, event_id)
	account = current_account


func get_message_type() -> StringName:
	return TYPE


func to_payload() -> Dictionary:
	if account == null:
		return {"account": {}}
	return {
		"account": {
			"open_id": account.open_id,
			"union_id": account.union_id,
			"name": account.name,
			"avatar_url": account.avatar_url,
			"scopes": Array(account.scopes),
		}
	}
