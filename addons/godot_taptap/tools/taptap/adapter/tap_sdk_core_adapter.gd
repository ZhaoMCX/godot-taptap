class_name TapSdkCoreAdapter
extends RefCounted

signal initialized
signal initialization_failed(error: TapSdkError)

enum State {
	UNINITIALIZED,
	INITIALIZING,
	READY,
}

var _bridge: Object
var _state: State = State.UNINITIALIZED


func _init(bridge: Object = null) -> void:
	_bridge = bridge
	if _bridge != null:
		_connect_bridge_signal("initialization_succeeded", _on_initialization_succeeded)
		_connect_bridge_signal("initialization_failed", _on_initialization_failed)


func is_available() -> bool:
	return _bridge != null


func is_initialized() -> bool:
	return _state == State.READY


func get_state() -> State:
	return _state


func initialize(config: TapSdkConfig, consent: TapPrivacyConsent) -> TapOperationResult:
	if not is_available():
		return _reject(TapSdkError.Code.UNAVAILABLE, "当前平台没有可用的 TapSDK 原生桥接")
	if _state == State.INITIALIZING:
		return _reject(TapSdkError.Code.BUSY, "TapSDK 正在初始化")
	if is_initialized():
		return _reject(TapSdkError.Code.INVALID_STATE, "TapSDK 已经初始化")
	if consent == null or not consent.privacy_policy_accepted:
		return _reject(TapSdkError.Code.CONSENT_REQUIRED, "用户同意隐私政策后才能初始化 TapSDK")
	if config == null:
		return _reject(TapSdkError.Code.INVALID_CONFIG, "TapSDK 配置不能为空")
	var validation_error := config.validate()
	if validation_error != null:
		return TapOperationResult.rejected(validation_error)

	_state = State.INITIALIZING
	if not bool(_bridge.call("initialize", JSON.stringify(config.to_dictionary()))):
		_state = State.UNINITIALIZED
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝初始化请求")
	return TapOperationResult.accepted_result()


func _connect_bridge_signal(signal_name: StringName, callback: Callable) -> void:
	if _bridge.has_signal(signal_name) and not _bridge.is_connected(signal_name, callback):
		_bridge.connect(signal_name, callback)


func _on_initialization_succeeded() -> void:
	_state = State.READY
	initialized.emit()


func _on_initialization_failed(native_code: int, message: String) -> void:
	_state = State.UNINITIALIZED
	initialization_failed.emit(
		TapSdkError.create(TapSdkError.Code.NATIVE_ERROR, message, native_code)
	)


func _reject(code: TapSdkError.Code, message: String) -> TapOperationResult:
	return TapOperationResult.rejected(TapSdkError.create(code, message))
