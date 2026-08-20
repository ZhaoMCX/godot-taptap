class_name LoginModuleBridgeFake
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)
signal login_succeeded(account_json: String)
signal login_cancelled
signal login_failed(native_code: int, message: String)
signal logout_succeeded
signal logout_failed(native_code: int, message: String)

var account: Dictionary = {}
var accept_calls := true


func initialize(_payload_json: String) -> bool:
	return accept_calls


func login(_scopes_json: String) -> bool:
	return accept_calls


func get_current_account() -> String:
	return JSON.stringify(account) if not account.is_empty() else ""


func logout() -> bool:
	return accept_calls
