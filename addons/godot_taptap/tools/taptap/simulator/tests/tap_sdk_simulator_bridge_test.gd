extends GdUnitTestSuite

const SOURCE_PATH := "user://tap_cloud_simulator_source.dat"
const COVER_PATH := "user://tap_cloud_simulator_cover.png"
const DATA_DOWNLOAD_PATH := "user://tap_cloud_simulator_download.dat"
const COVER_DOWNLOAD_PATH := "user://tap_cloud_simulator_download.png"


func before() -> void:
	_write_file(SOURCE_PATH, PackedByteArray([1, 2, 3, 4]))
	_write_file(COVER_PATH, PackedByteArray([5, 6, 7]))


func after() -> void:
	for path: String in [SOURCE_PATH, COVER_PATH, DATA_DOWNLOAD_PATH, COVER_DOWNLOAD_PATH]:
		_remove_file(path)


func test_simulator_supports_full_cloud_save_crud_and_file_downloads() -> void:
	var bridge := auto_free(TapSdkSimulatorBridge.new()) as TapSdkSimulatorBridge
	var created: Array[Dictionary] = []
	var updated: Array[Dictionary] = []
	var listed: Array[Array] = []
	var deleted: Array[Dictionary] = []
	var data_downloaded := [0]
	var cover_downloaded := [0]
	bridge.cloud_save_archive_created.connect(
		func(raw: String) -> void: created.append(JSON.parse_string(raw))
	)
	bridge.cloud_save_archive_updated.connect(
		func(raw: String) -> void: updated.append(JSON.parse_string(raw))
	)
	bridge.cloud_save_archive_list_received.connect(
		func(raw: String) -> void: listed.append(JSON.parse_string(raw))
	)
	bridge.cloud_save_archive_deleted.connect(
		func(raw: String) -> void: deleted.append(JSON.parse_string(raw))
	)
	bridge.cloud_save_data_downloaded.connect(func() -> void: data_downloaded[0] += 1)
	bridge.cloud_save_cover_downloaded.connect(func() -> void: cover_downloaded[0] += 1)

	bridge.login("[]")
	await get_tree().process_frame
	var metadata := JSON.stringify({"name": "slot_1", "summary": "summary", "extra": "v1", "playtime": 5})
	bridge.cloud_save_create(metadata, _absolute(SOURCE_PATH), _absolute(COVER_PATH))
	await get_tree().process_frame
	var uuid := str(created[0].uuid)
	var file_id := str(created[0].file_id)
	bridge.cloud_save_list()
	await get_tree().process_frame
	assert_int(listed[0].size()).is_equal(1)

	bridge.cloud_save_download_data(uuid, file_id, _absolute(DATA_DOWNLOAD_PATH))
	bridge.cloud_save_download_cover(uuid, file_id, _absolute(COVER_DOWNLOAD_PATH))
	await get_tree().process_frame
	assert_bool(
		FileAccess.get_file_as_bytes(DATA_DOWNLOAD_PATH) == PackedByteArray([1, 2, 3, 4])
	).is_true()
	assert_bool(
		FileAccess.get_file_as_bytes(COVER_DOWNLOAD_PATH) == PackedByteArray([5, 6, 7])
	).is_true()
	assert_int(data_downloaded[0]).is_equal(1)
	assert_int(cover_downloaded[0]).is_equal(1)

	bridge.cloud_save_update(uuid, metadata, _absolute(SOURCE_PATH), "")
	await get_tree().process_frame
	assert_str(updated.back().uuid).is_equal(uuid)
	assert_str(updated.back().file_id).is_not_equal(file_id)
	bridge.cloud_save_delete(uuid)
	await get_tree().process_frame
	assert_str(deleted[0].uuid).is_equal(uuid)


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\", "/")


func _write_file(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
