extends GdUnitTestSuite

const APPLICATION_SCENE := preload("res://game/applications/godot_taptap_test_application.tscn")


func test_godot_taptap_test_application_scene_can_start() -> void:
	var application := auto_free(APPLICATION_SCENE.instantiate()) as GodotTapTapTestApplication
	add_child(application)

	assert_object(application).is_instanceof(GodotTapTapTestApplication)
	assert_bool(application.is_inside_tree()).is_true()
	assert_object(application.get_taptap_access_feature()).is_not_null()
	assert_object(application.tap_sdk_core_module).is_instanceof(TapSdkCoreModule)
	assert_object(application.tap_tap_cloud_save_module).is_instanceof(TapTapCloudSaveModule)
	assert_object(application.taptap_access_panel).is_instanceof(TapTapAccessPanel)
	assert_object(application.get_taptap_cloud_save_feature()).is_instanceof(TapTapCloudSaveFeature)
	assert_object(application.taptap_cloud_save_panel).is_instanceof(TapTapCloudSavePanel)
	assert_object(application.cloud_save_local_store).is_instanceof(SampleSaveCloudLocalStore)
	assert_int(application.cloud_save_local_store.get_slot_definitions().size()).is_equal(3)
