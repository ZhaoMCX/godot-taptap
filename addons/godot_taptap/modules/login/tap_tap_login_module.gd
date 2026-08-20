class_name TapTapLoginModule
extends GFModule

signal account_changed(event: TapTapAccountChangedEvent)
signal login_cancelled(event: TapTapLoginCancelledEvent)
signal command_completed(event: GFCommandCompletedEvent)

var _adapter: TapTapLoginAdapter
var _account: TapTapAccountSnapshot
var _pending_command_id := ""
var _pending_kind: StringName = &""


func configure(adapter: TapTapLoginAdapter) -> void:
	_disconnect_adapter()
	_adapter = adapter
	if _adapter != null:
		_adapter.login_succeeded.connect(_on_login_succeeded)
		_adapter.login_cancelled.connect(_on_login_cancelled)
		_adapter.login_failed.connect(_on_login_failed)
		_adapter.logout_succeeded.connect(_on_logout_succeeded)
		_adapter.logout_failed.connect(_on_logout_failed)


func submit_restore_account(command: TapTapRestoreAccountCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _can_submit(command.command_id):
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "TapTap 账号操作正在进行")
	if _adapter == null or not _adapter.is_ready():
		return GFSubmitResult.rejected_result(command.command_id, &"not_initialized", "TapSDK 尚未初始化")

	_account = _adapter.get_current_account()
	account_changed.emit(TapTapAccountChangedEvent.new(_account, command.command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command.command_id, true))
	return GFSubmitResult.accepted_result(command.command_id)


func submit_login(command: TapTapLoginCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _can_submit(command.command_id):
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "TapTap 账号操作正在进行")
	_pending_command_id = command.command_id
	_pending_kind = &"login"
	var result := _adapter.login(command.scopes) if _adapter != null else null
	if result == null or not result.accepted:
		_clear_pending()
		var message := "TapTap Login Module 尚未配置" if result == null else result.error.message
		var code := &"not_configured" if result == null else _error_code(result.error)
		return GFSubmitResult.rejected_result(command.command_id, code, message)
	return GFSubmitResult.accepted_result(command.command_id)


func submit_logout(command: TapTapLogoutCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _can_submit(command.command_id):
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "TapTap 账号操作正在进行")
	_pending_command_id = command.command_id
	_pending_kind = &"logout"
	var result := _adapter.logout() if _adapter != null else null
	if result == null or not result.accepted:
		_clear_pending()
		var message := "TapTap Login Module 尚未配置" if result == null else result.error.message
		var code := &"not_configured" if result == null else _error_code(result.error)
		return GFSubmitResult.rejected_result(command.command_id, code, message)
	return GFSubmitResult.accepted_result(command.command_id)


func get_snapshot() -> TapTapLoginSnapshot:
	return TapTapLoginSnapshot.new(_account, not _pending_command_id.is_empty())


func _exit_tree() -> void:
	_disconnect_adapter()


func _on_login_succeeded(account: TapTapAccountSnapshot) -> void:
	_account = account
	_complete_account_change(true)


func _on_login_cancelled() -> void:
	var command_id := _pending_command_id
	_clear_pending()
	login_cancelled.emit(TapTapLoginCancelledEvent.new(command_id))
	command_completed.emit(
		GFCommandCompletedEvent.new(command_id, false, &"login_cancelled", "用户取消了 TapTap 登录")
	)


func _on_login_failed(error: TapSdkError) -> void:
	_complete_failure(error)


func _on_logout_succeeded() -> void:
	_account = null
	_complete_account_change(true)


func _on_logout_failed(error: TapSdkError) -> void:
	_complete_failure(error)


func _complete_account_change(succeeded: bool) -> void:
	var command_id := _pending_command_id
	_clear_pending()
	account_changed.emit(TapTapAccountChangedEvent.new(_account, command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, succeeded))


func _complete_failure(error: TapSdkError) -> void:
	var command_id := _pending_command_id
	_clear_pending()
	command_completed.emit(
		GFCommandCompletedEvent.new(command_id, false, _error_code(error), error.message)
	)


func _can_submit(_command_id: String) -> bool:
	return _pending_command_id.is_empty()


func _clear_pending() -> void:
	_pending_command_id = ""
	_pending_kind = &""


func _validate_command(command: GFCommand) -> GFSubmitResult:
	if not GFMessageValidator.is_valid_command(command):
		var command_id := "" if command == null else command.command_id
		return GFSubmitResult.rejected_result(command_id, &"invalid_command", "账号命令无效")
	return null


func _disconnect_adapter() -> void:
	if _adapter == null:
		return
	if _adapter.login_succeeded.is_connected(_on_login_succeeded):
		_adapter.login_succeeded.disconnect(_on_login_succeeded)
	if _adapter.login_cancelled.is_connected(_on_login_cancelled):
		_adapter.login_cancelled.disconnect(_on_login_cancelled)
	if _adapter.login_failed.is_connected(_on_login_failed):
		_adapter.login_failed.disconnect(_on_login_failed)
	if _adapter.logout_succeeded.is_connected(_on_logout_succeeded):
		_adapter.logout_succeeded.disconnect(_on_logout_succeeded)
	if _adapter.logout_failed.is_connected(_on_logout_failed):
		_adapter.logout_failed.disconnect(_on_logout_failed)


func _error_code(error: TapSdkError) -> StringName:
	return StringName(TapSdkError.Code.keys()[error.code].to_lower())
