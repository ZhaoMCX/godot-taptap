extends GdUnitTestSuite


func test_synchronous_success_keeps_causation_and_completes_once() -> void:
	var context := _module_context()
	var bridge: ComplianceModuleBridgeFake = context.bridge
	var module: TapTapComplianceModule = context.module
	bridge.result_on_start = 500
	var events: Array[TapComplianceResultEvent] = []
	var completions: Array[GFCommandCompletedEvent] = []
	module.compliance_result.connect(func(event: TapComplianceResultEvent) -> void: events.append(event))
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	var command := TapComplianceStartCommand.new("open-id")

	assert_bool(module.submit_start(command).accepted).is_true()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].causation_id).is_equal(command.command_id)
	assert_bool(completions[0].succeeded).is_true()
	assert_bool(module.get_snapshot().checking).is_false()


func test_notice_is_intermediate_and_unknown_fails_closed() -> void:
	var context := _module_context()
	var bridge: ComplianceModuleBridgeFake = context.bridge
	var module: TapTapComplianceModule = context.module
	var completions: Array[GFCommandCompletedEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	module.submit_start(TapComplianceStartCommand.new("open-id"))
	bridge.emit_result(1095)
	assert_int(completions.size()).is_equal(0)
	assert_bool(module.get_snapshot().checking).is_true()
	bridge.emit_result(42)
	assert_int(completions.size()).is_equal(1)
	assert_bool(completions[0].succeeded).is_false()
	assert_str(completions[0].error_code).is_equal("compliance_42")


func test_exit_cancels_pending_check_and_completes_on_session_end() -> void:
	var context := _module_context()
	var module: TapTapComplianceModule = context.module
	var completions: Array[GFCommandCompletedEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	var start := TapComplianceStartCommand.new("open-id")
	module.submit_start(start)
	var exit_command := TapComplianceExitCommand.new()
	assert_bool(module.submit_exit(exit_command).accepted).is_true()
	assert_int(completions.size()).is_equal(2)
	assert_str(completions[0].causation_id).is_equal(start.command_id)
	assert_str(completions[0].error_code).is_equal("compliance_cancelled")
	assert_str(completions[1].causation_id).is_equal(exit_command.command_id)
	assert_bool(completions[1].succeeded).is_true()


func _module_context() -> Dictionary:
	var bridge := auto_free(ComplianceModuleBridgeFake.new()) as ComplianceModuleBridgeFake
	var core := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = true
	core.initialize(config, consent)
	bridge.initialization_succeeded.emit()
	var adapter := auto_free(TapTapComplianceAdapter.new(bridge, core)) as TapTapComplianceAdapter
	var module := auto_free(TapTapComplianceModule.new()) as TapTapComplianceModule
	module.configure(adapter)
	return {"bridge": bridge, "module": module}
