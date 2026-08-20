class_name TapSdkError
extends RefCounted

enum Code {
	NONE,
	UNAVAILABLE,
	INVALID_CONFIG,
	CONSENT_REQUIRED,
	NOT_INITIALIZED,
	BUSY,
	INVALID_STATE,
	INVALID_RESPONSE,
	LOCAL_IO_ERROR,
	NATIVE_ERROR,
}

var code: Code = Code.NONE
var native_code: int = 0
var message: String = ""


static func create(
		p_code: Code,
		p_message: String,
		p_native_code: int = 0
) -> TapSdkError:
	var error := TapSdkError.new()
	error.code = p_code
	error.message = p_message
	error.native_code = p_native_code
	return error
