extends GdUnitTestSuite


func test_restore_and_login_emit_account_events_with_causation() -> void:
	var context := _module_context()
	var bridge: LoginModuleBridgeFake = context.bridge
	var module: TapTapLoginModule = context.module
	var events: Array[TapTapAccountChangedEvent] = []
	var completions: Array[GFCommandCompletedEvent] = []
	module.account_changed.connect(func(event: TapTapAccountChangedEvent) -> void: events.append(event))
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))

	bridge.account = {"open_id": "restored"}
	var restore := TapTapRestoreAccountCommand.new()
	assert_bool(module.submit_restore_account(restore).accepted).is_true()
	assert_str(events[0].account.open_id).is_equal("restored")
	assert_str(events[0].causation_id).is_equal(restore.command_id)

	var login := TapTapLoginCommand.new()
	assert_bool(module.submit_login(login).accepted).is_true()
	bridge.login_succeeded.emit(JSON.stringify({"open_id": "logged-in"}))
	assert_str(events.back().account.open_id).is_equal("logged-in")
	assert_str(completions.back().causation_id).is_equal(login.command_id)
	assert_bool(completions.back().succeeded).is_true()


func test_login_cancelled_completes_command_as_failure() -> void:
	var context := _module_context()
	var bridge: LoginModuleBridgeFake = context.bridge
	var module: TapTapLoginModule = context.module
	var completions: Array[GFCommandCompletedEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	var login := TapTapLoginCommand.new()
	module.submit_login(login)
	bridge.login_cancelled.emit()
	assert_bool(completions[0].succeeded).is_false()
	assert_str(completions[0].error_code).is_equal("login_cancelled")


func _module_context() -> Dictionary:
	var bridge := auto_free(LoginModuleBridgeFake.new()) as LoginModuleBridgeFake
	var core := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = true
	core.initialize(config, consent)
	bridge.initialization_succeeded.emit()
	var adapter := auto_free(TapTapLoginAdapter.new(bridge, core)) as TapTapLoginAdapter
	var module := auto_free(TapTapLoginModule.new()) as TapTapLoginModule
	module.configure(adapter)
	return {"bridge": bridge, "module": module}
