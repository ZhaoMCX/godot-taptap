class_name TapTapLoginAdapter
extends RefCounted

signal login_succeeded(account: TapTapAccountSnapshot)
signal login_cancelled
signal login_failed(error: TapSdkError)
signal logout_succeeded
signal logout_failed(error: TapSdkError)

var _bridge: Object
var _core: TapSdkCoreAdapter
var _login_in_progress := false


func _init(bridge: Object, core_adapter: TapSdkCoreAdapter) -> void:
	_bridge = bridge
	_core = core_adapter
	if _bridge != null:
		_connect_bridge_signal("login_succeeded", _on_login_succeeded)
		_connect_bridge_signal("login_cancelled", _on_login_cancelled)
		_connect_bridge_signal("login_failed", _on_login_failed)
		_connect_bridge_signal("logout_succeeded", _on_logout_succeeded)
		_connect_bridge_signal("logout_failed", _on_logout_failed)


func login(scopes: PackedStringArray = PackedStringArray(["public_profile"])) -> TapOperationResult:
	var readiness_error := _validate_ready()
	if readiness_error != null:
		return TapOperationResult.rejected(readiness_error)
	if _login_in_progress:
		return _reject(TapSdkError.Code.BUSY, "TapTap 登录请求正在进行")
	if not scopes.has("basic_info") and not scopes.has("public_profile"):
		return _reject(
			TapSdkError.Code.INVALID_CONFIG,
			"TapTap 登录 scopes 必须包含 basic_info 或 public_profile"
		)
	_login_in_progress = true
	if not bool(_bridge.call("login", JSON.stringify(Array(scopes)))):
		_login_in_progress = false
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝登录请求")
	return TapOperationResult.accepted_result()


func get_current_account() -> TapTapAccountSnapshot:
	if _validate_ready() != null:
		return null
	var parsed := _parse_json_dictionary(_bridge.call("get_current_account"))
	return null if parsed.is_empty() else TapTapAccountSnapshot.from_dictionary(parsed)


func is_ready() -> bool:
	return _validate_ready() == null


func logout() -> TapOperationResult:
	var readiness_error := _validate_ready()
	if readiness_error != null:
		return TapOperationResult.rejected(readiness_error)
	if _login_in_progress:
		return _reject(TapSdkError.Code.BUSY, "登录请求进行中，不能登出")
	if not bool(_bridge.call("logout")):
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝登出请求")
	return TapOperationResult.accepted_result()


func _validate_ready() -> TapSdkError:
	if _bridge == null:
		return TapSdkError.create(TapSdkError.Code.UNAVAILABLE, "当前平台没有可用的 TapSDK 原生桥接")
	if not _core.is_initialized():
		return TapSdkError.create(TapSdkError.Code.NOT_INITIALIZED, "TapSDK 尚未初始化")
	return null


func _connect_bridge_signal(signal_name: StringName, callback: Callable) -> void:
	if _bridge.has_signal(signal_name) and not _bridge.is_connected(signal_name, callback):
		_bridge.connect(signal_name, callback)


func _on_login_succeeded(account_json: String) -> void:
	_login_in_progress = false
	var parsed := _parse_json_dictionary(account_json)
	if parsed.is_empty():
		login_failed.emit(
			TapSdkError.create(TapSdkError.Code.INVALID_RESPONSE, "TapTap 账号数据格式无效")
		)
		return
	login_succeeded.emit(TapTapAccountSnapshot.from_dictionary(parsed))


func _on_login_cancelled() -> void:
	_login_in_progress = false
	login_cancelled.emit()


func _on_login_failed(native_code: int, message: String) -> void:
	_login_in_progress = false
	login_failed.emit(TapSdkError.create(TapSdkError.Code.NATIVE_ERROR, message, native_code))


func _on_logout_succeeded() -> void:
	logout_succeeded.emit()


func _on_logout_failed(native_code: int, message: String) -> void:
	logout_failed.emit(TapSdkError.create(TapSdkError.Code.NATIVE_ERROR, message, native_code))


func _parse_json_dictionary(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw
	if raw is String and not raw.is_empty():
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			return parsed
	return {}


func _reject(code: TapSdkError.Code, message: String) -> TapOperationResult:
	return TapOperationResult.rejected(TapSdkError.create(code, message))
