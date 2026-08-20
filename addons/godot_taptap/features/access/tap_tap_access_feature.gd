class_name TapTapAccessFeature
extends GFFeature

signal state_changed(state: State, message: String)
signal account_changed(account: TapTapAccountSnapshot)
signal access_granted(account: TapTapAccountSnapshot)

enum State {
	WAITING_CONSENT,
	READY_TO_INITIALIZE,
	INITIALIZING,
	SIGNED_OUT,
	LOGGING_IN,
	CHECKING_COMPLIANCE,
	ACCESS_GRANTED,
	RESTRICTED,
	RETRYABLE_ERROR,
}

var _core_module: TapSdkCoreModule
var _login_module: TapTapLoginModule
var _compliance_module: TapTapComplianceModule
var _privacy_accepted := false
var _account: TapTapAccountSnapshot
var _state: State = State.WAITING_CONSENT
var _status_message := "请先阅读并同意隐私政策"
var _pending_logout_message := "已退出登录"
var _initialize_command_id := ""
var _login_command_id := ""
var _logout_command_id := ""
var _logout_requested := false


func configure(
		core_module: TapSdkCoreModule,
		login_module: TapTapLoginModule,
		compliance_module: TapTapComplianceModule,
) -> void:
	_disconnect_dependencies()
	_core_module = core_module
	_login_module = login_module
	_compliance_module = compliance_module
	_core_module.sdk_initialized.connect(_on_sdk_initialized)
	_core_module.command_completed.connect(_on_core_command_completed)
	_login_module.account_changed.connect(_on_account_changed_event)
	_login_module.login_cancelled.connect(_on_login_cancelled)
	_login_module.command_completed.connect(_on_login_command_completed)
	_compliance_module.compliance_result.connect(_on_compliance_result)


func get_state() -> State:
	return _state


func get_status_message() -> String:
	return _status_message


func get_account() -> TapTapAccountSnapshot:
	return _account


func set_privacy_accepted(accepted: bool) -> void:
	if _core_module != null and _core_module.get_snapshot().state == TapSdkCoreModule.State.READY:
		return
	_privacy_accepted = accepted
	if accepted:
		_set_state(State.READY_TO_INITIALIZE, "隐私政策已同意，可以初始化 TapSDK")
	else:
		_set_state(State.WAITING_CONSENT, "请先阅读并同意隐私政策")


func initialize_sdk() -> GFSubmitResult:
	if _core_module == null:
		return _reject_not_configured("TapSDK Access Feature 尚未配置")
	var command := TapSdkInitializeCommand.new(_privacy_accepted)
	_initialize_command_id = command.command_id
	var result := _core_module.submit_initialize(command)
	if result.accepted:
		_set_state(State.INITIALIZING, "正在初始化 TapSDK")
	else:
		_initialize_command_id = ""
		_set_state(State.RETRYABLE_ERROR, result.error_message)
	return result


func login() -> GFSubmitResult:
	if _login_module == null:
		return _reject_not_configured("TapTap Login Module 尚未配置")
	var command := TapTapLoginCommand.new()
	_login_command_id = command.command_id
	var result := _login_module.submit_login(command)
	if result.accepted:
		_set_state(State.LOGGING_IN, "正在打开 TapTap 登录")
	else:
		_login_command_id = ""
		_set_state(State.RETRYABLE_ERROR, result.error_message)
	return result


func logout() -> GFSubmitResult:
	if _login_module == null:
		return _reject_not_configured("TapTap Login Module 尚未配置")
	_pending_logout_message = "已退出 TapTap 账号"
	_logout_requested = true
	if _account != null and _compliance_module != null:
		_compliance_module.submit_exit(TapComplianceExitCommand.new())
	var command := TapTapLogoutCommand.new()
	_logout_command_id = command.command_id
	var result := _login_module.submit_logout(command)
	if not result.accepted:
		_logout_command_id = ""
		_set_state(State.RETRYABLE_ERROR, result.error_message)
	return result


func retry() -> GFSubmitResult:
	if _account != null:
		return recheck_compliance()
	return login()


func recheck_compliance() -> GFSubmitResult:
	if _account == null:
		_set_state(State.SIGNED_OUT, "没有可用于防沉迷检查的账号")
		return GFSubmitResult.rejected_result("", &"missing_account", _status_message)
	return _start_compliance(_account)


func _exit_tree() -> void:
	_disconnect_dependencies()


func _on_sdk_initialized(_event: TapSdkInitializedEvent) -> void:
	_initialize_command_id = ""
	var result := _login_module.submit_restore_account(TapTapRestoreAccountCommand.new())
	if not result.accepted:
		_set_state(State.RETRYABLE_ERROR, result.error_message)


func _on_core_command_completed(event: GFCommandCompletedEvent) -> void:
	if event.causation_id != _initialize_command_id or event.succeeded:
		return
	_initialize_command_id = ""
	_set_state(State.RETRYABLE_ERROR, "TapSDK 初始化失败：%s" % event.error_message)


func _on_account_changed_event(event: TapTapAccountChangedEvent) -> void:
	_account = event.account
	account_changed.emit(_account)
	if _account == null:
		var message := _pending_logout_message if event.causation_id == _logout_command_id else "TapSDK 已初始化，请登录 TapTap"
		_logout_requested = false
		_set_state(State.SIGNED_OUT, message)
		return
	_login_command_id = ""
	_start_compliance(_account)


func _on_login_cancelled(_event: TapTapLoginCancelledEvent) -> void:
	_login_command_id = ""
	_set_state(State.SIGNED_OUT, "用户取消了 TapTap 登录")


func _on_login_command_completed(event: GFCommandCompletedEvent) -> void:
	if event.causation_id == _login_command_id and not event.succeeded:
		_login_command_id = ""
		if event.error_code != &"login_cancelled":
			_set_state(State.RETRYABLE_ERROR, "TapTap 登录失败：%s" % event.error_message)
	elif event.causation_id == _logout_command_id:
		_logout_command_id = ""
		if not event.succeeded:
			_set_state(State.RETRYABLE_ERROR, "TapTap 登出失败：%s" % event.error_message)


func _on_compliance_result(event: TapComplianceResultEvent) -> void:
	var result := event.result
	match result.category:
		TapComplianceResult.Category.ACCESS_GRANTED:
			_set_state(State.ACCESS_GRANTED, "防沉迷校验通过，可以进入游戏")
			access_granted.emit(_account)
		TapComplianceResult.Category.SESSION_ENDED:
			if not _logout_requested:
				_logout_for_compliance("防沉迷会话已退出，请重新登录")
		TapComplianceResult.Category.SWITCH_ACCOUNT:
			_logout_for_compliance("用户选择切换账号，请重新登录")
		TapComplianceResult.Category.TOKEN_EXPIRED:
			_logout_for_compliance("TapTap 登录已过期，请重新登录")
		TapComplianceResult.Category.PERIOD_RESTRICTED:
			_set_state(State.RESTRICTED, "当前时段禁止游戏（1030）")
		TapComplianceResult.Category.DURATION_LIMIT:
			_set_state(State.RESTRICTED, "旧版时长限制结果（1050）")
		TapComplianceResult.Category.AGE_RESTRICTED:
			_set_state(State.RESTRICTED, "当前账号受到年龄限制（1100）")
		TapComplianceResult.Category.NOTICE:
			_set_state(State.CHECKING_COMPLIANCE, "防沉迷提示已打开，等待后续结果（1095）")
		TapComplianceResult.Category.NETWORK_OR_CLIENT_ERROR:
			_set_state(State.RETRYABLE_ERROR, "防沉迷网络或 Client 配置错误（1200）")
		TapComplianceResult.Category.REAL_NAME_CANCELLED:
			_set_state(State.RETRYABLE_ERROR, "用户关闭了实名认证，可以重试（9002）")
		_:
			_set_state(State.RESTRICTED, "未知防沉迷结果 %d，已拒绝进入游戏" % result.code)


func _start_compliance(account: TapTapAccountSnapshot) -> GFSubmitResult:
	_set_state(State.CHECKING_COMPLIANCE, "正在进行防沉迷校验")
	var result := _compliance_module.submit_start(TapComplianceStartCommand.new(account.open_id))
	if not result.accepted:
		_set_state(State.RETRYABLE_ERROR, result.error_message)
	return result


func _logout_for_compliance(message: String) -> void:
	_pending_logout_message = message
	_logout_requested = true
	_compliance_module.submit_exit(TapComplianceExitCommand.new())
	var command := TapTapLogoutCommand.new()
	_logout_command_id = command.command_id
	var result := _login_module.submit_logout(command)
	if not result.accepted:
		_logout_command_id = ""
		_account = null
		account_changed.emit(null)
		_set_state(State.SIGNED_OUT, message)


func _disconnect_dependencies() -> void:
	if _core_module != null:
		if _core_module.sdk_initialized.is_connected(_on_sdk_initialized):
			_core_module.sdk_initialized.disconnect(_on_sdk_initialized)
		if _core_module.command_completed.is_connected(_on_core_command_completed):
			_core_module.command_completed.disconnect(_on_core_command_completed)
	if _login_module != null:
		if _login_module.account_changed.is_connected(_on_account_changed_event):
			_login_module.account_changed.disconnect(_on_account_changed_event)
		if _login_module.login_cancelled.is_connected(_on_login_cancelled):
			_login_module.login_cancelled.disconnect(_on_login_cancelled)
		if _login_module.command_completed.is_connected(_on_login_command_completed):
			_login_module.command_completed.disconnect(_on_login_command_completed)
	if _compliance_module != null and _compliance_module.compliance_result.is_connected(_on_compliance_result):
		_compliance_module.compliance_result.disconnect(_on_compliance_result)


func _set_state(next_state: State, message: String) -> void:
	_state = next_state
	_status_message = message
	state_changed.emit(_state, _status_message)


func _reject_not_configured(message: String) -> GFSubmitResult:
	_set_state(State.RETRYABLE_ERROR, message)
	return GFSubmitResult.rejected_result("", &"not_configured", message)
