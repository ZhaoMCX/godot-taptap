extends GdUnitTestSuite

const PANEL_SCENE := preload(
	"res://addons/godot_taptap/features/cloud_save/scenes/taptap_cloud_save_panel.tscn"
)


func after() -> void:
	var path := CloudSaveFeatureLocalStoreFake.UPLOAD_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_panel_renders_host_slot_and_local_backup_action() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	var panel := auto_free(PANEL_SCENE.instantiate()) as TapTapCloudSavePanel
	add_child(panel)
	panel.configure(feature)

	feature.activate("player-a")
	await get_tree().process_frame
	assert_int((panel.get_node("%SlotList") as VBoxContainer).get_child_count()).is_equal(1)
	assert_str((panel.get_node("%SlotTitleLabel") as Label).text).is_equal("存档 1")
	assert_str((panel.get_node("%PrimaryButton") as Button).text).is_equal("创建云备份")


func test_panel_shows_two_explicit_conflict_actions() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.archives = [bridge.make_archive()]
	var panel := auto_free(PANEL_SCENE.instantiate()) as TapTapCloudSavePanel
	add_child(panel)
	panel.configure(feature)

	feature.activate("player-a")
	await get_tree().process_frame
	assert_bool((panel.get_node("%UseCloudButton") as Button).visible).is_true()
	assert_bool((panel.get_node("%KeepLocalButton") as Button).visible).is_true()
	assert_bool((panel.get_node("%PrimaryButton") as Button).visible).is_false()


func test_primary_and_delete_confirmation_dispatch_feature_actions() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	var panel := auto_free(PANEL_SCENE.instantiate()) as TapTapCloudSavePanel
	add_child(panel)
	panel.configure(feature)
	feature.activate("player-a")
	await get_tree().process_frame

	(panel.get_node("%PrimaryButton") as Button).pressed.emit()
	assert_str(bridge.last_kind).is_equal("create")
	(panel.get_node("%DeleteButton") as Button).pressed.emit()
	assert_str(bridge.last_kind).is_equal("create")
	(panel.get_node("%ConfirmationDialog") as ConfirmationDialog).confirmed.emit()
	assert_str(bridge.last_kind).is_equal("delete")
	assert_int(feature.get_snapshot().slots[0].status).is_equal(
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY
	)


func test_conflict_cloud_action_and_logout_require_confirmation() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.archives = [bridge.make_archive()]
	var panel := auto_free(PANEL_SCENE.instantiate()) as TapTapCloudSavePanel
	add_child(panel)
	panel.configure(feature)
	var logout_events: Array[bool] = []
	panel.logout_requested.connect(func() -> void: logout_events.append(true))
	feature.activate("player-a")
	await get_tree().process_frame

	(panel.get_node("%UseCloudButton") as Button).pressed.emit()
	assert_array(local.loaded_slots).is_empty()
	(panel.get_node("%ConfirmationDialog") as ConfirmationDialog).confirmed.emit()
	assert_array(local.loaded_slots).contains_exactly(["slot_1"])
	await get_tree().process_frame
	(panel.get_node("%LogoutButton") as Button).pressed.emit()
	assert_array(logout_events).is_empty()
	(panel.get_node("%ConfirmationDialog") as ConfirmationDialog).confirmed.emit()
	assert_int(logout_events.size()).is_equal(1)


func test_busy_state_disables_refresh_and_logout() -> void:
	var context := _context()
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	bridge.hold_list = true
	var panel := auto_free(PANEL_SCENE.instantiate()) as TapTapCloudSavePanel
	add_child(panel)
	panel.configure(feature)

	feature.activate("player-a")
	await get_tree().process_frame
	assert_bool((panel.get_node("%RefreshButton") as Button).disabled).is_true()
	assert_bool((panel.get_node("%LogoutButton") as Button).disabled).is_true()
	bridge.complete_list()


func _context() -> Dictionary:
	var bridge := auto_free(CloudSaveFeatureBridgeFake.new()) as CloudSaveFeatureBridgeFake
	var core := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = true
	core.initialize(config, consent)
	bridge.initialization_succeeded.emit()
	var adapter := auto_free(TapTapCloudSaveAdapter.new(bridge, core)) as TapTapCloudSaveAdapter
	var module := auto_free(TapTapCloudSaveModule.new()) as TapTapCloudSaveModule
	module.configure(adapter)
	var local := auto_free(CloudSaveFeatureLocalStoreFake.new()) as CloudSaveFeatureLocalStoreFake
	var sync := auto_free(CloudSaveFeatureSyncStoreFake.new()) as CloudSaveFeatureSyncStoreFake
	var feature := auto_free(TapTapCloudSaveFeature.new()) as TapTapCloudSaveFeature
	feature.configure(module, local, sync)
	return {"bridge": bridge, "local": local, "feature": feature}
