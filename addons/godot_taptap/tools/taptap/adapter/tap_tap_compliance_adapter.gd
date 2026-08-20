class_name TapTapComplianceAdapter
extends RefCounted

signal result_received(result: TapComplianceResult)

var _bridge: Object
var _core: TapSdkCoreAdapter


func _init(bridge: Object, core_adapter: TapSdkCoreAdapter) -> void:
	_bridge = bridge
	_core = core_adapter
	if _bridge != null and _bridge.has_signal("compliance_result"):
		_bridge.connect("compliance_result", _on_compliance_result)


func start(open_id: String) -> TapOperationResult:
	var readiness_error := _validate_ready()
	if readiness_error != null:
		return TapOperationResult.rejected(readiness_error)
	if open_id.strip_edges().is_empty():
		return _reject(TapSdkError.Code.INVALID_CONFIG, "防沉迷检查需要非空的 open_id")
	if not bool(_bridge.call("start_compliance", open_id)):
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝防沉迷请求")
	return TapOperationResult.accepted_result()


func exit() -> TapOperationResult:
	var readiness_error := _validate_ready()
	if readiness_error != null:
		return TapOperationResult.rejected(readiness_error)
	if not bool(_bridge.call("exit_compliance")):
		return _reject(TapSdkError.Code.NATIVE_ERROR, "TapSDK 原生桥接拒绝退出防沉迷请求")
	return TapOperationResult.accepted_result()


func _validate_ready() -> TapSdkError:
	if _bridge == null:
		return TapSdkError.create(TapSdkError.Code.UNAVAILABLE, "当前平台没有可用的 TapSDK 原生桥接")
	if not _core.is_initialized():
		return TapSdkError.create(TapSdkError.Code.NOT_INITIALIZED, "TapSDK 尚未初始化")
	return null


func _on_compliance_result(result_json: String) -> void:
	var parsed: Variant = JSON.parse_string(result_json)
	if not parsed is Dictionary or not parsed.has("code"):
		var invalid := TapComplianceResult.new()
		invalid.metadata = {"error": "防沉迷结果格式无效"}
		result_received.emit(invalid)
		return
	result_received.emit(TapComplianceResult.from_dictionary(parsed))


func _reject(code: TapSdkError.Code, message: String) -> TapOperationResult:
	return TapOperationResult.rejected(TapSdkError.create(code, message))
