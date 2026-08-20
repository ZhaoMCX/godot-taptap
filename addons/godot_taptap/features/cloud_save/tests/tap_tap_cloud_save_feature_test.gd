extends GdUnitTestSuite


func after() -> void:
	var path := CloudSaveFeatureLocalStoreFake.UPLOAD_PATH
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_local_only_upload_creates_remote_and_marks_slot_synced() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")

	feature.activate("player-a")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY)
	assert_bool(feature.request_upload("slot_1").accepted).is_true()
	assert_str(bridge.last_kind).is_equal("create")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.SYNCED)


func test_first_remote_and_local_pair_is_conflict_then_cloud_is_imported_and_loaded() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.archives = [bridge.make_archive()]

	feature.activate("player-a")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.CONFLICT)
	assert_bool(feature.resolve_conflict("slot_1", true).accepted).is_true()
	assert_array(local.imported_slots).contains_exactly(["slot_1"])
	assert_array(local.loaded_slots).contains_exactly(["slot_1"])
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.SYNCED)


func test_list_failure_keeps_local_load_available_and_blocks_upload() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.fail_next_list = true

	feature.activate("player-a")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED)
	assert_str(feature.request_upload("slot_1").error_code).is_equal("cloud_unconfirmed")
	assert_bool(feature.request_load("slot_1").accepted).is_true()
	assert_array(local.loaded_slots).contains_exactly(["slot_1"])


func test_cover_download_finishes_before_queued_player_upload() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-new")
	var archive := bridge.make_archive()
	archive.cover_size = 4
	bridge.archives = [archive]
	bridge.hold_cover = true

	feature.activate("player-a")
	assert_str(bridge.last_kind).is_equal("download_cover")
	assert_bool(feature.request_upload("slot_1").accepted).is_true()
	assert_str(bridge.last_kind).is_equal("download_cover")
	bridge.complete_cover()
	assert_str(bridge.last_kind).is_equal("update")


func test_duplicate_remote_name_marks_slot_error_and_prevents_mutation() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.archives = [bridge.make_archive(), bridge.make_archive("slot_1", "archive-2")]

	feature.activate("player-a")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.ERROR)
	assert_str(feature.request_upload("slot_1").error_code).is_equal("slot_error")


func test_uuid_only_delete_clears_remote_and_next_upload_creates_archive() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var feature: TapTapCloudSaveFeature = context.feature
	local.set_local("slot_1", "local-a")
	bridge.archives = [bridge.make_archive("slot_1", "deleted-uuid")]

	feature.activate("player-a")
	assert_bool(feature.request_delete("slot_1").accepted).is_true()
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY)
	assert_object(_slot(feature).remote).is_null()
	assert_bool(feature.request_upload("slot_1").accepted).is_true()
	assert_str(bridge.last_kind).is_equal("create")
	assert_str(_slot(feature).remote.uuid).is_not_equal("deleted-uuid")
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.SYNCED)


func test_all_slot_statuses_follow_local_remote_and_sync_state() -> void:
	assert_int(_status_for(false, null, {})).is_equal(TapTapCloudSaveSlotSnapshot.Status.EMPTY)
	assert_int(_status_for(true, null, {})).is_equal(TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY)
	assert_int(_status_for(false, _archive(), {})).is_equal(TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY)
	assert_int(_status_for(true, _archive(), _record())).is_equal(TapTapCloudSaveSlotSnapshot.Status.SYNCED)
	assert_int(_status_for(true, _archive(), _record("old-local"))).is_equal(
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED
	)
	assert_int(_status_for(true, _archive("new-file"), _record())).is_equal(
		TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED
	)
	assert_int(_status_for(true, _archive("new-file"), _record("old-local"))).is_equal(
		TapTapCloudSaveSlotSnapshot.Status.CONFLICT
	)


func test_download_import_failure_keeps_remote_retryable_and_removes_temporary_file() -> void:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var sync: CloudSaveFeatureSyncStoreFake = context.sync
	var feature: TapTapCloudSaveFeature = context.feature
	local.fail_import = true
	bridge.archives = [bridge.make_archive()]
	feature.activate("player-a")
	var destination := sync.get_account_path() + "/slot_1.download"

	assert_bool(feature.request_load("slot_1").accepted).is_true()
	assert_int(_slot(feature).status).is_equal(TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY)
	assert_str(feature.get_snapshot().status_message).contains("导入失败")
	assert_bool(FileAccess.file_exists(destination)).is_false()


func test_old_account_callback_does_not_confirm_new_account() -> void:
	var context := _context()
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var sync: CloudSaveFeatureSyncStoreFake = context.sync
	var feature: TapTapCloudSaveFeature = context.feature
	bridge.hold_list = true
	assert_bool(feature.activate("player-a").accepted).is_true()
	feature.deactivate()
	assert_bool(feature.activate("player-b").accepted).is_false()

	bridge.complete_list()
	assert_bool(feature.get_snapshot().active).is_true()
	assert_bool(feature.get_snapshot().cloud_confirmed).is_false()
	assert_str(sync.account_key).is_equal("player-b")
	assert_bool(feature.refresh().accepted).is_true()
	assert_bool(feature.get_snapshot().cloud_confirmed).is_true()


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
	return {"bridge": bridge, "module": module, "local": local, "sync": sync, "feature": feature}


func _slot(feature: TapTapCloudSaveFeature) -> TapTapCloudSaveSlotSnapshot:
	return feature.get_snapshot().slots[0]


func _status_for(
		local_exists: bool,
		archive: Variant,
		record: Dictionary,
) -> TapTapCloudSaveSlotSnapshot.Status:
	var context := _context()
	var local: CloudSaveFeatureLocalStoreFake = context.local
	var bridge: CloudSaveFeatureBridgeFake = context.bridge
	var sync: CloudSaveFeatureSyncStoreFake = context.sync
	var feature: TapTapCloudSaveFeature = context.feature
	if local_exists:
		local.set_local("slot_1", "local")
	if archive != null:
		bridge.archives = [archive]
	if not record.is_empty():
		sync.records["slot_1"] = record
	feature.activate("player-a")
	return _slot(feature).status


func _archive(file_id: String = "file-1") -> Dictionary:
	var archive := CloudSaveFeatureBridgeFake.new().make_archive()
	archive.file_id = file_id
	return archive


func _record(local_fingerprint: String = "local") -> Dictionary:
	return {
		"local_fingerprint": local_fingerprint,
		"remote_uuid": "archive-1",
		"remote_file_id": "file-1",
		"remote_modified_time": 100,
	}
