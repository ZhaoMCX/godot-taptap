extends GdUnitTestSuite


func test_initialize_completes_only_after_native_callback() -> void:
	var bridge := auto_free(CoreModuleBridgeFake.new()) as CoreModuleBridgeFake
	var adapter := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var module := auto_free(TapSdkCoreModule.new()) as TapSdkCoreModule
	module.configure(adapter, _valid_config())
	var initialized: Array[TapSdkInitializedEvent] = []
	var completions: Array[GFCommandCompletedEvent] = []
	module.sdk_initialized.connect(func(event: TapSdkInitializedEvent) -> void: initialized.append(event))
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	var command := TapSdkInitializeCommand.new(true)

	var submission := module.submit_initialize(command)
	assert_bool(submission.accepted).is_true()
	assert_int(completions.size()).is_equal(0)
	bridge.initialization_succeeded.emit()

	assert_int(initialized.size()).is_equal(1)
	assert_str(initialized[0].causation_id).is_equal(command.command_id)
	assert_bool(completions[0].succeeded).is_true()
	assert_int(module.get_snapshot().state).is_equal(TapSdkCoreModule.State.READY)


func test_initialize_rejects_missing_consent_and_propagates_native_failure() -> void:
	var bridge := auto_free(CoreModuleBridgeFake.new()) as CoreModuleBridgeFake
	var adapter := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var module := auto_free(TapSdkCoreModule.new()) as TapSdkCoreModule
	module.configure(adapter, _valid_config())
	var rejected := module.submit_initialize(TapSdkInitializeCommand.new(false))
	assert_bool(rejected.accepted).is_false()
	assert_str(rejected.error_code).is_equal("consent_required")

	var completions: Array[GFCommandCompletedEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	module.submit_initialize(TapSdkInitializeCommand.new(true))
	bridge.initialization_failed.emit(23, "native init failed")
	assert_bool(completions[0].succeeded).is_false()
	assert_str(completions[0].error_message).is_equal("native init failed")


func test_synchronous_initialization_callback_keeps_ready_state_and_causation() -> void:
	var bridge := auto_free(CoreModuleBridgeFake.new()) as CoreModuleBridgeFake
	bridge.succeed_synchronously = true
	var adapter := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var module := auto_free(TapSdkCoreModule.new()) as TapSdkCoreModule
	module.configure(adapter, _valid_config())
	var completions: Array[GFCommandCompletedEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	var command := TapSdkInitializeCommand.new(true)
	assert_bool(module.submit_initialize(command).accepted).is_true()
	assert_int(module.get_snapshot().state).is_equal(TapSdkCoreModule.State.READY)
	assert_str(completions[0].causation_id).is_equal(command.command_id)


func _valid_config() -> TapSdkConfig:
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	return config
