class_name ComplianceModuleBridgeFake
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)
signal compliance_result(result_json: String)

var result_on_start := -1


func initialize(_payload_json: String) -> bool:
	return true


func start_compliance(_open_id: String) -> bool:
	if result_on_start >= 0:
		emit_result(result_on_start)
	return true


func exit_compliance() -> bool:
	emit_result(1000)
	return true


func emit_result(code: int) -> void:
	compliance_result.emit(JSON.stringify({"code": code, "metadata": {}}))
