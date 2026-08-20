extends GdUnitTestSuite

const APPLICATION_SCENE := preload(
	"res://addons/godot_taptap/applications/tap_tap_application.tscn"
)


func test_application_composes_modules_feature_and_panel() -> void:
	var application := auto_free(APPLICATION_SCENE.instantiate()) as TapTapApplication
	add_child(application)

	assert_object(application).is_instanceof(TapTapApplication)
	assert_object(application.tap_sdk_core_module).is_instanceof(TapSdkCoreModule)
	assert_object(application.tap_tap_login_module).is_instanceof(TapTapLoginModule)
	assert_object(application.tap_tap_compliance_module).is_instanceof(TapTapComplianceModule)
	assert_object(application.tap_tap_cloud_save_module).is_instanceof(TapTapCloudSaveModule)
	assert_object(application.taptap_access_feature).is_instanceof(TapTapAccessFeature)
	assert_object(application.taptap_access_panel).is_instanceof(TapTapAccessPanel)
	assert_object(application.taptap_cloud_save_feature).is_instanceof(TapTapCloudSaveFeature)
	assert_object(application.taptap_cloud_save_panel).is_instanceof(TapTapCloudSavePanel)
	assert_object(application.cloud_save_local_store).is_instanceof(TapCloudSaveLocalStore)
	assert_bool(application.tap_sdk_core_module.get_parent() == application).is_true()
	assert_bool(application.tap_tap_login_module.get_parent() == application).is_true()
	assert_bool(application.tap_tap_compliance_module.get_parent() == application).is_true()
	assert_bool(application.tap_tap_cloud_save_module.get_parent() == application).is_true()
	assert_bool(application.taptap_access_feature.get_parent() == application).is_true()
	assert_bool(application.taptap_access_panel.get_parent() == application).is_true()
	assert_bool(application.taptap_cloud_save_feature.get_parent() == application).is_true()
	assert_bool(application.taptap_cloud_save_panel.get_parent() == application).is_true()
	assert_bool(
		application.taptap_access_feature.find_child("TapTapAccessPanel", false, false) == null
	).is_true()


func test_access_granted_switches_from_access_panel_to_cloud_save_panel() -> void:
	var application := auto_free(APPLICATION_SCENE.instantiate()) as TapTapApplication
	add_child(application)
	var account := TapTapAccountSnapshot.from_dictionary({"open_id": "player", "name": "Player"})

	application.taptap_access_feature.access_granted.emit(account)
	assert_bool(application.taptap_access_panel.visible).is_false()
	assert_bool(application.taptap_cloud_save_panel.visible).is_true()
	assert_bool(application.taptap_cloud_save_feature.get_snapshot().active).is_true()

	application.taptap_access_feature.account_changed.emit(null)
	assert_bool(application.taptap_access_panel.visible).is_true()
	assert_bool(application.taptap_cloud_save_panel.visible).is_false()


func test_access_restriction_closes_cloud_save_page() -> void:
	var application := auto_free(APPLICATION_SCENE.instantiate()) as TapTapApplication
	add_child(application)
	var account := TapTapAccountSnapshot.from_dictionary({"open_id": "player"})
	application.taptap_access_feature.access_granted.emit(account)

	application.taptap_access_feature.state_changed.emit(
		TapTapAccessFeature.State.RESTRICTED, "当前账号受限"
	)
	assert_bool(application.taptap_access_panel.visible).is_true()
	assert_bool(application.taptap_cloud_save_panel.visible).is_false()
	assert_bool(application.taptap_cloud_save_feature.get_snapshot().active).is_false()
