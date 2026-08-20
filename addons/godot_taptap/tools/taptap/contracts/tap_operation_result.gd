class_name TapOperationResult
extends RefCounted

var accepted: bool = false
var error: TapSdkError


static func accepted_result() -> TapOperationResult:
	var result := TapOperationResult.new()
	result.accepted = true
	return result


static func rejected(error_value: TapSdkError) -> TapOperationResult:
	var result := TapOperationResult.new()
	result.error = error_value
	return result
