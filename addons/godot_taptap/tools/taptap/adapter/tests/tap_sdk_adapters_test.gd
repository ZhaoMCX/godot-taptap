extends GdUnitTestSuite


func test_core_requires_consent_and_reports_native_completion() -> void:
	var bridge := auto_free(FakeTapSdkBridge.new()) as FakeTapSdkBridge
	var adapters := auto_free(TapSdkAdapters.new(bridge)) as TapSdkAdapters
	var initialized := [false]
	adapters.core.initialized.connect(func() -> void: initialized[0] = true)

	var rejected := adapters.core.initialize(_valid_config(), TapPrivacyConsent.new())
	assert_bool(rejected.accepted).is_false()
	assert_int(rejected.error.code).is_equal(TapSdkError.Code.CONSENT_REQUIRED)

	var accepted := adapters.core.initialize(_valid_config(), _accepted_consent())
	assert_bool(accepted.accepted).is_true()
	assert_bool(adapters.core.is_initialized()).is_false()
	bridge.succeed_initialization()
	assert_bool(initialized[0]).is_true()
	assert_bool(adapters.core.is_initialized()).is_true()


func test_login_maps_success_cancel_failure_and_hides_tokens() -> void:
	var context := _initialized_adapters()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapters: TapSdkAdapters = context.adapters
	var accounts: Array[TapTapAccountSnapshot] = []
	var cancellations := [0]
	var failures: Array[TapSdkError] = []
	adapters.login.login_succeeded.connect(func(account: TapTapAccountSnapshot) -> void: accounts.append(account))
	adapters.login.login_cancelled.connect(func() -> void: cancellations[0] += 1)
	adapters.login.login_failed.connect(func(error: TapSdkError) -> void: failures.append(error))

	assert_bool(adapters.login.login().accepted).is_true()
	bridge.succeed_login({"open_id": "open", "access_token": "hidden", "scopes": ["public_profile"]})
	assert_int(accounts.size()).is_equal(1)
	assert_str(accounts[0].open_id).is_equal("open")
	var property_names := PackedStringArray()
	for property: Dictionary in accounts[0].get_property_list():
		property_names.append(str(property.name))
	assert_bool(property_names.has("access_token")).is_false()

	assert_bool(adapters.login.login().accepted).is_true()
	bridge.login_cancelled.emit()
	assert_int(cancellations[0]).is_equal(1)
	assert_bool(adapters.login.login().accepted).is_true()
	bridge.fail_login()
	assert_int(failures.size()).is_equal(1)


func test_login_rejects_scope_without_identity_permission() -> void:
	var context := _initialized_adapters()
	var adapters: TapSdkAdapters = context.adapters
	var result := adapters.login.login(PackedStringArray(["user_friends"]))
	assert_bool(result.accepted).is_false()
	assert_int(result.error.code).is_equal(TapSdkError.Code.INVALID_CONFIG)


func test_compliance_maps_all_codes_and_unknown_fails_closed() -> void:
	var context := _initialized_adapters()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapters: TapSdkAdapters = context.adapters
	var results: Array[TapComplianceResult] = []
	adapters.compliance.result_received.connect(
		func(result: TapComplianceResult) -> void: results.append(result)
	)
	var expected := {
		500: TapComplianceResult.Category.ACCESS_GRANTED,
		1000: TapComplianceResult.Category.SESSION_ENDED,
		1001: TapComplianceResult.Category.SWITCH_ACCOUNT,
		1030: TapComplianceResult.Category.PERIOD_RESTRICTED,
		1050: TapComplianceResult.Category.DURATION_LIMIT,
		1095: TapComplianceResult.Category.NOTICE,
		1100: TapComplianceResult.Category.AGE_RESTRICTED,
		1200: TapComplianceResult.Category.NETWORK_OR_CLIENT_ERROR,
		9001: TapComplianceResult.Category.TOKEN_EXPIRED,
		9002: TapComplianceResult.Category.REAL_NAME_CANCELLED,
		42: TapComplianceResult.Category.UNKNOWN,
	}
	for code: int in expected:
		bridge.emit_compliance(code)
		assert_int(results.back().category).is_equal(expected[code])


func test_unavailable_adapters_reject_calls() -> void:
	var adapters := auto_free(TapSdkAdapters.new()) as TapSdkAdapters
	var result := adapters.core.initialize(_valid_config(), _accepted_consent())
	assert_bool(result.accepted).is_false()
	assert_int(result.error.code).is_equal(TapSdkError.Code.UNAVAILABLE)


func _initialized_adapters() -> Dictionary:
	var bridge := auto_free(FakeTapSdkBridge.new()) as FakeTapSdkBridge
	var adapters := auto_free(TapSdkAdapters.new(bridge)) as TapSdkAdapters
	adapters.core.initialize(_valid_config(), _accepted_consent())
	bridge.succeed_initialization()
	return {"bridge": bridge, "adapters": adapters}


func _valid_config() -> TapSdkConfig:
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	return config


func _accepted_consent() -> TapPrivacyConsent:
	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = true
	return consent
