extends GdUnitTestSuite

const ARCHIVE_PATH := "user://tap_cloud_save_adapter_test.dat"
const COVER_PATH := "user://tap_cloud_save_adapter_test.png"


func before() -> void:
	_write_file(ARCHIVE_PATH, PackedByteArray([1, 2, 3]))
	_write_file(COVER_PATH, PackedByteArray([4, 5]))


func after() -> void:
	_remove_file(ARCHIVE_PATH)
	_remove_file(COVER_PATH)


func test_create_uses_absolute_paths_and_maps_archive() -> void:
	var context := _initialized_context()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapter: TapTapCloudSaveAdapter = context.adapter
	var archives: Array[TapCloudSaveArchiveSnapshot] = []
	adapter.archive_created.connect(func(value: TapCloudSaveArchiveSnapshot) -> void: archives.append(value))

	var metadata := TapCloudSaveMetadata.new("slot_1", "summary", "v1", 12)
	assert_bool(adapter.create_archive(metadata, ARCHIVE_PATH, COVER_PATH).accepted).is_true()
	assert_str(bridge.last_cloud_save_call.kind).is_equal("create")
	assert_bool(str(bridge.last_cloud_save_call.archive_path).is_absolute_path()).is_true()
	bridge.cloud_save_archive_created.emit(JSON.stringify(_archive_data()))
	assert_str(archives[0].uuid).is_equal("uuid-1")
	assert_int(archives[0].modified_time).is_equal(200)


func test_list_download_status_and_failure_callbacks_are_mapped() -> void:
	var context := _initialized_context()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapter: TapTapCloudSaveAdapter = context.adapter
	var lists: Array[Array] = []
	var downloads: Array[String] = []
	var failures: Array[TapSdkError] = []
	var statuses: Array[int] = []
	adapter.archive_list_received.connect(func(values: Array[TapCloudSaveArchiveSnapshot]) -> void: lists.append(values))
	adapter.data_downloaded.connect(func(path: String) -> void: downloads.append(path))
	adapter.request_failed.connect(func(error: TapSdkError) -> void: failures.append(error))
	adapter.status_received.connect(func(code: int) -> void: statuses.append(code))

	assert_bool(adapter.list_archives().accepted).is_true()
	bridge.cloud_save_archive_list_received.emit(JSON.stringify([_archive_data()]))
	assert_int(lists[0].size()).is_equal(1)
	assert_bool(adapter.download_data("uuid-1", "file-1", "user://download.dat").accepted).is_true()
	assert_int(adapter.list_archives().error.code).is_equal(TapSdkError.Code.BUSY)
	bridge.cloud_save_data_downloaded.emit()
	assert_str(downloads[0]).is_equal("user://download.dat")
	assert_bool(adapter.list_archives().accepted).is_true()
	bridge.cloud_save_request_failed.emit(TapTapCloudSaveAdapter.LOCAL_IO_NATIVE_CODE, "write failed")
	assert_int(failures[0].code).is_equal(TapSdkError.Code.LOCAL_IO_ERROR)
	bridge.cloud_save_status.emit(300002)
	assert_array(statuses).contains_exactly([300002])


func test_invalid_paths_and_missing_files_are_rejected_locally() -> void:
	var context := _initialized_context()
	var adapter: TapTapCloudSaveAdapter = context.adapter
	var metadata := TapCloudSaveMetadata.new("slot", "summary")
	assert_int(adapter.create_archive(metadata, "res://project.godot").error.code).is_equal(
		TapSdkError.Code.INVALID_CONFIG
	)
	assert_int(adapter.create_archive(metadata, "user://missing.dat").error.code).is_equal(
		TapSdkError.Code.INVALID_CONFIG
	)
	assert_int(adapter.download_cover("uuid", "file", "res://cover.png").error.code).is_equal(
		TapSdkError.Code.INVALID_CONFIG
	)


func test_delete_accepts_uuid_only_response_and_ignores_duplicate_callback() -> void:
	var context := _initialized_context()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapter: TapTapCloudSaveAdapter = context.adapter
	var deleted: Array[TapCloudSaveArchiveSnapshot] = []
	adapter.archive_deleted.connect(
		func(value: TapCloudSaveArchiveSnapshot) -> void: deleted.append(value)
	)

	assert_bool(adapter.delete_archive("uuid-1").accepted).is_true()
	bridge.cloud_save_archive_deleted.emit(JSON.stringify({"uuid": "uuid-1"}))
	assert_int(deleted.size()).is_equal(1)
	assert_str(deleted[0].uuid).is_equal("uuid-1")
	assert_str(deleted[0].name).is_empty()
	bridge.cloud_save_archive_deleted.emit(JSON.stringify({"uuid": "uuid-1"}))
	assert_int(deleted.size()).is_equal(1)


func test_mismatched_callback_does_not_complete_current_operation() -> void:
	var context := _initialized_context()
	var bridge: FakeTapSdkBridge = context.bridge
	var adapter: TapTapCloudSaveAdapter = context.adapter
	var lists: Array[Array] = []
	adapter.archive_list_received.connect(
		func(values: Array[TapCloudSaveArchiveSnapshot]) -> void: lists.append(values)
	)

	assert_bool(adapter.list_archives().accepted).is_true()
	bridge.cloud_save_data_downloaded.emit()
	assert_int(adapter.delete_archive("uuid-1").error.code).is_equal(TapSdkError.Code.BUSY)
	bridge.cloud_save_archive_list_received.emit("[]")
	assert_int(lists.size()).is_equal(1)
	assert_bool(adapter.delete_archive("uuid-1").accepted).is_true()
	bridge.cloud_save_archive_list_received.emit("[]")
	assert_int(adapter.list_archives().error.code).is_equal(TapSdkError.Code.BUSY)
	bridge.cloud_save_archive_deleted.emit(JSON.stringify({"uuid": "uuid-1"}))
	assert_bool(adapter.list_archives().accepted).is_true()


func _initialized_context() -> Dictionary:
	var bridge := auto_free(FakeTapSdkBridge.new()) as FakeTapSdkBridge
	var core := auto_free(TapSdkCoreAdapter.new(bridge)) as TapSdkCoreAdapter
	var config := TapSdkConfig.new()
	config.client_id = "client-id"
	config.client_token = "client-token"
	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = true
	core.initialize(config, consent)
	bridge.succeed_initialization()
	var adapter := auto_free(TapTapCloudSaveAdapter.new(bridge, core)) as TapTapCloudSaveAdapter
	return {"bridge": bridge, "adapter": adapter}


func _archive_data() -> Dictionary:
	return {
		"uuid": "uuid-1", "file_id": "file-1", "name": "slot_1", "summary": "summary",
		"extra": "v1", "playtime": 12, "save_size": 3, "cover_size": 2,
		"created_time": 100, "modified_time": 200,
	}


func _write_file(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
