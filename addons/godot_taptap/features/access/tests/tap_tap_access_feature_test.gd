extends GdUnitTestSuite


func test_feature_is_gf_node_and_login_success_grants_access() -> void:
	var context := _context()
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	assert_bool(feature is GFFeature).is_true()
	_initialize(context)
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.SIGNED_OUT)

	feature.login()
	bridge.succeed_login({"open_id": "player", "name": "Player"})
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.CHECKING_COMPLIANCE)
	assert_str(bridge.last_compliance_open_id).is_equal("player")
	bridge.emit_compliance(500)
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.ACCESS_GRANTED)


func test_restored_account_starts_compliance_without_login() -> void:
	var context := _context()
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	bridge.account = {"open_id": "restored"}
	_initialize(context)
	assert_str(bridge.last_compliance_open_id).is_equal("restored")
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.CHECKING_COMPLIANCE)


func test_synchronous_compliance_success_is_not_overwritten() -> void:
	var context := _context()
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	bridge.compliance_result_on_start = 500
	_initialize(context)
	feature.login()
	bridge.succeed_login({"open_id": "player"})
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.ACCESS_GRANTED)


func test_restrictions_unknown_and_retryable_codes_fail_closed() -> void:
	for code: int in [1030, 1050, 1100, 42, 1200, 9002]:
		var context := _logged_in_context()
		var feature: TapTapAccessFeature = context.feature
		var bridge: AccessFeatureBridgeFake = context.bridge
		bridge.emit_compliance(code)
		var expected := (
			TapTapAccessFeature.State.RETRYABLE_ERROR
			if code in [1200, 9002]
			else TapTapAccessFeature.State.RESTRICTED
		)
		assert_int(feature.get_state()).is_equal(expected)


func test_switch_account_logs_out_and_returns_signed_out() -> void:
	var context := _logged_in_context()
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	bridge.emit_compliance(1001)
	bridge.succeed_logout()
	assert_object(feature.get_account()).is_null()
	assert_int(feature.get_state()).is_equal(TapTapAccessFeature.State.SIGNED_OUT)
	assert_str(feature.get_status_message()).contains("切换账号")


func _logged_in_context() -> Dictionary:
	var context := _context()
	_initialize(context)
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	feature.login()
	bridge.succeed_login({"open_id": "player"})
	return context


func _initialize(context: Dictionary) -> void:
	var feature: TapTapAccessFeature = context.feature
	var bridge: AccessFeatureBridgeFake = context.bridge
	feature.set_privacy_accepted(true)
	feature.initialize_sdk()
	bridge.initialization_succeeded.emit()


func _context() -> Dictionary:
	var bridge := auto_free(AccessFeatureBridgeFake.new()) as AccessFeatureBridgeFake
	var adapters := auto_free(TapSdkAdapters.new(bridge)) as TapSdkAdapters
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	var core := auto_free(TapSdkCoreModule.new()) as TapSdkCoreModule
	core.configure(adapters.core, config)
	var login := auto_free(TapTapLoginModule.new()) as TapTapLoginModule
	login.configure(adapters.login)
	var compliance := auto_free(TapTapComplianceModule.new()) as TapTapComplianceModule
	compliance.configure(adapters.compliance)
	var feature := auto_free(TapTapAccessFeature.new()) as TapTapAccessFeature
	feature.configure(core, login, compliance)
	return {
		"bridge": bridge,
		"adapters": adapters,
		"core": core,
		"login": login,
		"compliance": compliance,
		"feature": feature,
	}
