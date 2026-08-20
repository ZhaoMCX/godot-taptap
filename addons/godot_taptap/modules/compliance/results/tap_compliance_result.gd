class_name TapComplianceResult
extends RefCounted

enum Category {
	ACCESS_GRANTED,
	SESSION_ENDED,
	SWITCH_ACCOUNT,
	PERIOD_RESTRICTED,
	DURATION_LIMIT,
	NOTICE,
	AGE_RESTRICTED,
	NETWORK_OR_CLIENT_ERROR,
	TOKEN_EXPIRED,
	REAL_NAME_CANCELLED,
	UNKNOWN,
}

const LOGIN_SUCCESS := 500
const EXITED := 1000
const SWITCH_ACCOUNT_CODE := 1001
const PERIOD_RESTRICT := 1030
const DURATION_LIMIT_CODE := 1050
const OPEN_ALERT_TIP := 1095
const AGE_RESTRICT := 1100
const INVALID_CLIENT_OR_NETWORK_ERROR := 1200
const TOKEN_EXPIRED_CODE := 9001
const REAL_NAME_STOP := 9002

var code: int = 0
var category: Category = Category.UNKNOWN
var metadata: Dictionary = {}


static func from_dictionary(data: Dictionary) -> TapComplianceResult:
	var result := TapComplianceResult.new()
	result.code = int(data.get("code", 0))
	var raw_metadata: Variant = data.get("metadata", {})
	if raw_metadata is Dictionary:
		result.metadata = raw_metadata.duplicate(true)
	result.category = _category_for_code(result.code)
	return result


static func _category_for_code(result_code: int) -> Category:
	match result_code:
		LOGIN_SUCCESS:
			return Category.ACCESS_GRANTED
		EXITED:
			return Category.SESSION_ENDED
		SWITCH_ACCOUNT_CODE:
			return Category.SWITCH_ACCOUNT
		PERIOD_RESTRICT:
			return Category.PERIOD_RESTRICTED
		DURATION_LIMIT_CODE:
			return Category.DURATION_LIMIT
		OPEN_ALERT_TIP:
			return Category.NOTICE
		AGE_RESTRICT:
			return Category.AGE_RESTRICTED
		INVALID_CLIENT_OR_NETWORK_ERROR:
			return Category.NETWORK_OR_CLIENT_ERROR
		TOKEN_EXPIRED_CODE:
			return Category.TOKEN_EXPIRED
		REAL_NAME_STOP:
			return Category.REAL_NAME_CANCELLED
		_:
			return Category.UNKNOWN
