class_name FakeTapSdkBridge
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)
signal login_succeeded(account_json: String)
signal login_cancelled
signal login_failed(native_code: int, message: String)
signal logout_succeeded
signal logout_failed(native_code: int, message: String)
signal compliance_result(result_json: String)
signal cloud_save_archive_created(archive_json: String)
signal cloud_save_archive_updated(archive_json: String)
signal cloud_save_archive_deleted(archive_json: String)
signal cloud_save_archive_list_received(archives_json: String)
signal cloud_save_data_downloaded
signal cloud_save_cover_downloaded
signal cloud_save_request_failed(native_code: int, message: String)
signal cloud_save_status(code: int)

var accept_calls := true
var last_initialize_payload: Dictionary = {}
var last_scopes: Array = []
var last_compliance_open_id := ""
var account: Dictionary = {}
var compliance_result_on_start := -1
var last_cloud_save_call: Dictionary = {}


func initialize(payload_json: String) -> bool:
	var parsed: Variant = JSON.parse_string(payload_json)
	if parsed is Dictionary:
		last_initialize_payload = parsed
	return accept_calls


func login(scopes_json: String) -> bool:
	var parsed: Variant = JSON.parse_string(scopes_json)
	if parsed is Array:
		last_scopes = parsed
	return accept_calls


func get_current_account() -> String:
	return JSON.stringify(account) if not account.is_empty() else ""


func logout() -> bool:
	return accept_calls


func start_compliance(open_id: String) -> bool:
	last_compliance_open_id = open_id
	if accept_calls and compliance_result_on_start >= 0:
		emit_compliance(compliance_result_on_start)
	return accept_calls


func exit_compliance() -> bool:
	if accept_calls:
		emit_compliance(TapComplianceResult.EXITED)
	return accept_calls


func cloud_save_create(metadata_json: String, archive_path: String, cover_path: String) -> bool:
	last_cloud_save_call = {
		"kind": "create",
		"metadata": JSON.parse_string(metadata_json),
		"archive_path": archive_path,
		"cover_path": cover_path,
	}
	return accept_calls


func cloud_save_list() -> bool:
	last_cloud_save_call = {"kind": "list"}
	return accept_calls


func cloud_save_download_data(uuid: String, file_id: String, destination_path: String) -> bool:
	last_cloud_save_call = {
		"kind": "download_data", "uuid": uuid, "file_id": file_id,
		"destination_path": destination_path,
	}
	return accept_calls


func cloud_save_update(
		uuid: String,
		metadata_json: String,
		archive_path: String,
		cover_path: String,
) -> bool:
	last_cloud_save_call = {
		"kind": "update",
		"uuid": uuid,
		"metadata": JSON.parse_string(metadata_json),
		"archive_path": archive_path,
		"cover_path": cover_path,
	}
	return accept_calls


func cloud_save_delete(uuid: String) -> bool:
	last_cloud_save_call = {"kind": "delete", "uuid": uuid}
	return accept_calls


func cloud_save_download_cover(uuid: String, file_id: String, destination_path: String) -> bool:
	last_cloud_save_call = {
		"kind": "download_cover", "uuid": uuid, "file_id": file_id,
		"destination_path": destination_path,
	}
	return accept_calls


func succeed_initialization() -> void:
	initialization_succeeded.emit()


func fail_initialization(code: int = 1, message: String = "init failed") -> void:
	initialization_failed.emit(code, message)


func succeed_login(account_data: Dictionary) -> void:
	account = account_data
	login_succeeded.emit(JSON.stringify(account_data))


func fail_login(code: int = 2, message: String = "login failed") -> void:
	login_failed.emit(code, message)


func succeed_logout() -> void:
	account.clear()
	logout_succeeded.emit()


func emit_compliance(result_code: int, metadata: Dictionary = {}) -> void:
	compliance_result.emit(JSON.stringify({"code": result_code, "metadata": metadata}))
