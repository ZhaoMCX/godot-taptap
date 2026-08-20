class_name AccessFeatureBridgeFake
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)
signal login_succeeded(account_json: String)
signal login_cancelled
signal login_failed(native_code: int, message: String)
signal logout_succeeded
signal logout_failed(native_code: int, message: String)
signal compliance_result(result_json: String)

var account: Dictionary = {}
var compliance_result_on_start := -1
var last_compliance_open_id := ""


func initialize(_payload_json: String) -> bool:
	return true


func login(_scopes_json: String) -> bool:
	return true


func get_current_account() -> String:
	return JSON.stringify(account) if not account.is_empty() else ""


func logout() -> bool:
	return true


func start_compliance(open_id: String) -> bool:
	last_compliance_open_id = open_id
	if compliance_result_on_start >= 0:
		emit_compliance(compliance_result_on_start)
	return true


func exit_compliance() -> bool:
	return true


func succeed_login(account_data: Dictionary) -> void:
	account = account_data
	login_succeeded.emit(JSON.stringify(account_data))


func succeed_logout() -> void:
	account.clear()
	logout_succeeded.emit()


func emit_compliance(code: int) -> void:
	compliance_result.emit(JSON.stringify({"code": code, "metadata": {}}))
