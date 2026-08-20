class_name TapTapComplianceModule
extends GFModule

signal compliance_result(event: TapComplianceResultEvent)
signal command_completed(event: GFCommandCompletedEvent)

var _adapter: TapTapComplianceAdapter
var _pending_command_id := ""
var _pending_kind: StringName = &""
var _last_result: TapComplianceResult


func configure(adapter: TapTapComplianceAdapter) -> void:
	_disconnect_adapter()
	_adapter = adapter
	if _adapter != null:
		_adapter.result_received.connect(_on_result_received)


func submit_start(command: TapComplianceStartCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _pending_command_id.is_empty():
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "防沉迷操作正在进行")
	_pending_command_id = command.command_id
	_pending_kind = &"start"
	var result := _adapter.start(command.open_id) if _adapter != null else null
	if result == null or not result.accepted:
		_clear_pending()
		var message := "TapTap Compliance Module 尚未配置" if result == null else result.error.message
		var code := &"not_configured" if result == null else _error_code(result.error)
		return GFSubmitResult.rejected_result(command.command_id, code, message)
	return GFSubmitResult.accepted_result(command.command_id)


func submit_exit(command: TapComplianceExitCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _pending_command_id.is_empty():
		var cancelled_command_id := _pending_command_id
		_clear_pending()
		command_completed.emit(
			GFCommandCompletedEvent.new(
				cancelled_command_id,
				false,
				&"compliance_cancelled",
				"防沉迷检查被退出命令取消",
			)
		)
	_pending_command_id = command.command_id
	_pending_kind = &"exit"
	var result := _adapter.exit() if _adapter != null else null
	if result == null or not result.accepted:
		_clear_pending()
		var message := "TapTap Compliance Module 尚未配置" if result == null else result.error.message
		var code := &"not_configured" if result == null else _error_code(result.error)
		return GFSubmitResult.rejected_result(command.command_id, code, message)
	return GFSubmitResult.accepted_result(command.command_id)


func get_snapshot() -> TapComplianceSnapshot:
	return TapComplianceSnapshot.new(not _pending_command_id.is_empty(), _last_result)


func _exit_tree() -> void:
	_disconnect_adapter()


func _on_result_received(result: TapComplianceResult) -> void:
	_last_result = result
	var command_id := _pending_command_id
	var pending_kind := _pending_kind
	var is_terminal := result.category != TapComplianceResult.Category.NOTICE
	if is_terminal and not command_id.is_empty():
		_clear_pending()
	compliance_result.emit(TapComplianceResultEvent.new(result, command_id))
	if not is_terminal:
		return
	if command_id.is_empty():
		return

	var succeeded := result.category == TapComplianceResult.Category.ACCESS_GRANTED
	if pending_kind == &"exit" and result.category == TapComplianceResult.Category.SESSION_ENDED:
		succeeded = true
	var error_code := &"" if succeeded else StringName("compliance_%d" % result.code)
	var error_message := "" if succeeded else "防沉迷结果拒绝继续：%d" % result.code
	command_completed.emit(
		GFCommandCompletedEvent.new(command_id, succeeded, error_code, error_message)
	)


func _validate_command(command: GFCommand) -> GFSubmitResult:
	if not GFMessageValidator.is_valid_command(command):
		var command_id := "" if command == null else command.command_id
		return GFSubmitResult.rejected_result(command_id, &"invalid_command", "防沉迷命令无效")
	return null


func _clear_pending() -> void:
	_pending_command_id = ""
	_pending_kind = &""


func _disconnect_adapter() -> void:
	if _adapter != null and _adapter.result_received.is_connected(_on_result_received):
		_adapter.result_received.disconnect(_on_result_received)


func _error_code(error: TapSdkError) -> StringName:
	return StringName(TapSdkError.Code.keys()[error.code].to_lower())
