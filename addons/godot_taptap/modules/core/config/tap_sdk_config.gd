class_name TapSdkConfig
extends RefCounted

var client_id: String = ""
var client_token: String = ""
var enable_debug_log: bool = false
var show_switch_account: bool = true


func validate() -> TapSdkError:
	if client_id.strip_edges().is_empty():
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "TapTap Client ID 不能为空")
	if client_token.strip_edges().is_empty():
		return TapSdkError.create(TapSdkError.Code.INVALID_CONFIG, "TapTap Client Token 不能为空")
	return null


func to_dictionary() -> Dictionary:
	return {
		"client_id": client_id,
		"client_token": client_token,
		"enable_debug_log": enable_debug_log,
		"show_switch_account": show_switch_account,
	}
