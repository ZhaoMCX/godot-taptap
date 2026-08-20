class_name CoreModuleBridgeFake
extends RefCounted

signal initialization_succeeded
signal initialization_failed(native_code: int, message: String)

var accept_calls := true
var succeed_synchronously := false


func initialize(_payload_json: String) -> bool:
	if accept_calls and succeed_synchronously:
		initialization_succeeded.emit()
	return accept_calls
