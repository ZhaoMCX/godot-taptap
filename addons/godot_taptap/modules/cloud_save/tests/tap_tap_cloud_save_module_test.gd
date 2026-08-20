extends GdUnitTestSuite

const ARCHIVE_PATH := "user://tap_cloud_save_module_test.dat"
const COVER_PATH := "user://tap_cloud_save_module_test.png"


func before() -> void:
	_write_file(ARCHIVE_PATH, PackedByteArray([1, 2, 3, 4]))
	_write_file(COVER_PATH, PackedByteArray([5, 6]))


func after() -> void:
	_remove_file(ARCHIVE_PATH)
	_remove_file(COVER_PATH)


func test_create_update_delete_keep_cache_and_causation() -> void:
	var context := _module_context()
	var module: TapTapCloudSaveModule = context.module
	var created: Array[TapCloudSaveArchiveCreatedEvent] = []
	var updated: Array[TapCloudSaveArchiveUpdatedEvent] = []
	var deleted: Array[TapCloudSaveArchiveDeletedEvent] = []
	var completions: Array[GFCommandCompletedEvent] = []
	module.archive_created.connect(func(event: TapCloudSaveArchiveCreatedEvent) -> void: created.append(event))
	module.archive_updated.connect(func(event: TapCloudSaveArchiveUpdatedEvent) -> void: updated.append(event))
	module.archive_deleted.connect(func(event: TapCloudSaveArchiveDeletedEvent) -> void: deleted.append(event))
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))

	var create := TapCloudSaveCreateCommand.new(_metadata("slot_1"), ARCHIVE_PATH, COVER_PATH)
	assert_bool(module.submit_create(create).accepted).is_true()
	assert_str(created[0].causation_id).is_equal(create.command_id)
	assert_int(module.get_snapshot().archives.size()).is_equal(1)

	var uuid := created[0].archive.uuid
	var update := TapCloudSaveUpdateCommand.new(uuid, _metadata("slot_2"), ARCHIVE_PATH)
	assert_bool(module.submit_update(update).accepted).is_true()
	assert_str(updated[0].archive.name).is_equal("slot_2")
	assert_str(module.get_snapshot().archives[0].file_id).is_equal("file-updated")

	var delete := TapCloudSaveDeleteCommand.new(uuid)
	assert_bool(module.submit_delete(delete).accepted).is_true()
	assert_str(deleted[0].causation_id).is_equal(delete.command_id)
	assert_int(module.get_snapshot().archives.size()).is_equal(0)
	assert_int(completions.size()).is_equal(3)
	assert_bool(completions.all(func(event: GFCommandCompletedEvent) -> bool: return event.succeeded)).is_true()


func test_list_and_downloads_emit_domain_event_before_completion() -> void:
	var context := _module_context()
	var bridge: CloudSaveModuleBridgeFake = context.bridge
	var module: TapTapCloudSaveModule = context.module
	bridge.archives = [bridge._default_archive()]
	var order: Array[String] = []
	module.archive_list_received.connect(func(_event: TapCloudSaveArchiveListReceivedEvent) -> void: order.append("list"))
	module.data_downloaded.connect(func(_event: TapCloudSaveDataDownloadedEvent) -> void: order.append("data"))
	module.cover_downloaded.connect(func(_event: TapCloudSaveCoverDownloadedEvent) -> void: order.append("cover"))
	module.command_completed.connect(func(_event: GFCommandCompletedEvent) -> void: order.append("complete"))

	assert_bool(module.submit_list(TapCloudSaveListCommand.new()).accepted).is_true()
	assert_array(order).contains_exactly(["list", "complete"])
	order.clear()
	assert_bool(module.submit_download_data(
		TapCloudSaveDownloadDataCommand.new("archive-1", "file-1", "user://download.dat")
	).accepted).is_true()
	assert_array(order).contains_exactly(["data", "complete"])
	order.clear()
	assert_bool(module.submit_download_cover(
		TapCloudSaveDownloadCoverCommand.new("archive-1", "file-1", "user://cover.png")
	).accepted).is_true()
	assert_array(order).contains_exactly(["cover", "complete"])


func test_validation_busy_status_and_native_errors_are_explicit() -> void:
	var context := _module_context()
	var bridge: CloudSaveModuleBridgeFake = context.bridge
	var module: TapTapCloudSaveModule = context.module
	var invalid_metadata := TapCloudSaveMetadata.new("中文名", "")
	var rejected := module.submit_create(TapCloudSaveCreateCommand.new(invalid_metadata, ARCHIVE_PATH))
	assert_bool(rejected.accepted).is_false()
	assert_str(rejected.error_code).is_equal("invalid_archive_name")

	bridge.hold_requests = true
	assert_bool(module.submit_list(TapCloudSaveListCommand.new()).accepted).is_true()
	assert_bool(module.get_snapshot().busy).is_true()
	assert_str(module.submit_list(TapCloudSaveListCommand.new()).error_code).is_equal("busy")
	bridge.complete_list()

	var completions: Array[GFCommandCompletedEvent] = []
	var statuses: Array[TapCloudSaveStatusEvent] = []
	module.command_completed.connect(func(event: GFCommandCompletedEvent) -> void: completions.append(event))
	module.status_changed.connect(func(event: TapCloudSaveStatusEvent) -> void: statuses.append(event))
	bridge.next_error_code = 400001
	assert_bool(module.submit_list(TapCloudSaveListCommand.new()).accepted).is_true()
	assert_str(completions.back().error_code).is_equal("rate_limited")
	bridge.emit_status(300001)
	assert_int(statuses[0].category).is_equal(TapCloudSaveStatusEvent.Category.LOGIN_REQUIRED)
	assert_int(module.get_snapshot().status_code).is_equal(300001)


func _module_context() -> Dictionary:
	var bridge := auto_free(CloudSaveModuleBridgeFake.new()) as CloudSaveModuleBridgeFake
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
	return {"bridge": bridge, "module": module}


func _metadata(name: String) -> TapCloudSaveMetadata:
	return TapCloudSaveMetadata.new(name, "存档摘要", "v1", 42)


func _write_file(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
