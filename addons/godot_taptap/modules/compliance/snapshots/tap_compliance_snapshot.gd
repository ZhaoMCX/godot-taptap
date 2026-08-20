class_name TapComplianceSnapshot
extends RefCounted

var checking: bool:
	get:
		return _checking

var last_result: TapComplianceResult:
	get:
		return _last_result

var _checking: bool
var _last_result: TapComplianceResult


func _init(is_checking: bool, result: TapComplianceResult) -> void:
	_checking = is_checking
	_last_result = result
