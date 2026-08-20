extends GdUnitTestSuite

const TEST_ROOT := "user://sample_save_module_test"
const DOWNLOAD_PATH := TEST_ROOT + "/download.json"


func before() -> void:
	_delete_test_root()


func after() -> void:
	_delete_test_root()


func test_first_run_seeds_only_first_slot_and_can_load_it() -> void:
	var module := auto_free(SampleSaveModule.new()) as SampleSaveModule
	module.save_root = TEST_ROOT
	add_child(module)

	assert_bool(module.read_slot("slot_1").exists).is_true()
	assert_bool(module.read_slot("slot_2").exists).is_false()
	assert_bool(module.load_slot("slot_1").succeeded).is_true()
	assert_str(module.get_active_slot_id()).is_equal("slot_1")
	assert_str(module.get_active_data().summary).contains("序章")


func test_valid_download_is_imported_and_invalid_download_preserves_local_data() -> void:
	var module := auto_free(SampleSaveModule.new()) as SampleSaveModule
	module.save_root = TEST_ROOT
	add_child(module)
	_write_download("slot_2", "第二章")

	assert_bool(module.import_download("slot_2", DOWNLOAD_PATH).succeeded).is_true()
	assert_str(module.read_slot("slot_2").summary).is_equal("第二章")
	var original_fingerprint := module.read_slot("slot_2").fingerprint
	_write_download("wrong_slot", "损坏数据")
	assert_bool(module.import_download("slot_2", DOWNLOAD_PATH).succeeded).is_false()
	assert_str(module.read_slot("slot_2").fingerprint).is_equal(original_fingerprint)


func test_prepare_upload_returns_snapshot_and_png_cover() -> void:
	var module := auto_free(SampleSaveModule.new()) as SampleSaveModule
	module.save_root = TEST_ROOT
	add_child(module)
	var payload := module.prepare_upload("slot_1")

	assert_object(payload).is_not_null()
	assert_bool(FileAccess.file_exists(payload.archive_path)).is_true()
	assert_bool(FileAccess.file_exists(payload.cover_path)).is_true()
	assert_str(payload.fingerprint).is_not_empty()


func _write_download(slot_id: String, summary: String) -> void:
	var file := FileAccess.open(DOWNLOAD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"slot_id": slot_id,
		"summary": summary,
		"playtime_seconds": 42,
		"updated_at": 100,
	}))


func _delete_test_root() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_ROOT)):
		GdUnitFileAccess.delete_directory(TEST_ROOT)
