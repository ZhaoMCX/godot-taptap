extends GdUnitTestSuite

const TEST_ROOT := "user://tap_cloud_save_sync_store_test"
const FailingSyncStore := preload(
	"res://addons/godot_taptap/tools/taptap/cloud_save/tests/fixtures/failing_tap_cloud_save_sync_store.gd"
)


func after() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(TEST_ROOT)):
		GdUnitFileAccess.delete_directory(TEST_ROOT)


func test_records_are_persisted_and_isolated_by_account() -> void:
	var store := TapCloudSaveSyncStore.new(TEST_ROOT)
	store.activate("player-a")
	assert_bool(store.set_record("slot_1", {"value": "a"})).is_true()

	var restored := TapCloudSaveSyncStore.new(TEST_ROOT)
	restored.activate("player-a")
	assert_str(restored.get_record("slot_1").value).is_equal("a")
	restored.activate("player-b")
	assert_dict(restored.get_record("slot_1")).is_empty()


func test_corrupted_json_is_treated_as_empty_state() -> void:
	var store := TapCloudSaveSyncStore.new(TEST_ROOT)
	store.activate("player-a")
	var path := store.get_account_path() + "/sync_state.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not-json")
	file.close()

	var restored := TapCloudSaveSyncStore.new(TEST_ROOT)
	restored.activate("player-a")
	assert_dict(restored.get_record("slot_1")).is_empty()


func test_failed_replace_preserves_memory_and_previous_file() -> void:
	var store := FailingSyncStore.new(TEST_ROOT)
	store.activate("player-a")
	assert_bool(store.set_record("slot_1", {"value": "old"})).is_true()
	store.fail_replace = true
	assert_bool(store.set_record("slot_1", {"value": "new"})).is_false()
	assert_str(store.get_record("slot_1").value).is_equal("old")

	var restored := TapCloudSaveSyncStore.new(TEST_ROOT)
	restored.activate("player-a")
	assert_str(restored.get_record("slot_1").value).is_equal("old")
