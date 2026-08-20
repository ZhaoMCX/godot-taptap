class_name TapCloudSaveLocalResult
extends RefCounted

var succeeded: bool
var error_code: StringName
var error_message: String


func _init(ok: bool, code: StringName = &"", message: String = "") -> void:
	succeeded = ok
	error_code = &"" if ok else code
	error_message = "" if ok else message


static func success_result() -> TapCloudSaveLocalResult:
	return TapCloudSaveLocalResult.new(true)


static func failure(code: StringName, message: String) -> TapCloudSaveLocalResult:
	return TapCloudSaveLocalResult.new(false, code, message)
