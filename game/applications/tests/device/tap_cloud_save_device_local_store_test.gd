extends GdUnitTestSuite

const TEST_DIRECTORY := TapCloudSaveDeviceLocalStore.TEST_DIRECTORY


func after() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY)):
		GdUnitFileAccess.delete_directory(TEST_DIRECTORY)


func test_device_local_store_round_trips_versions() -> void:
	var store := auto_free(TapCloudSaveDeviceLocalStore.new()) as TapCloudSaveDeviceLocalStore
	add_child(store)
	assert_bool(store.prepare_for_launch()).is_true()
	assert_bool(store.write_version(1)).is_true()
	assert_int(store.get_version()).is_equal(1)
	assert_str(store.get_slot_definitions()[0].archive_name).starts_with("gf_device_")
	var payload := store.prepare_upload(TapCloudSaveDeviceLocalStore.SLOT_ID)
	assert_str(payload.summary).is_equal("device-v1")

	var download_path := TEST_DIRECTORY + "/download.json"
	var file := FileAccess.open(download_path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(TapCloudSaveDeviceLocalStore.SAVE_PATH))
	file.close()
	store.remove_local()
	assert_bool(store.read_slot(TapCloudSaveDeviceLocalStore.SLOT_ID).exists).is_false()
	assert_bool(store.import_download(TapCloudSaveDeviceLocalStore.SLOT_ID, download_path).succeeded).is_true()
	assert_bool(store.load_slot(TapCloudSaveDeviceLocalStore.SLOT_ID).succeeded).is_true()
	assert_int(store.loaded_version).is_equal(1)
