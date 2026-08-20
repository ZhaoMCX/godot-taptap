class_name TapCloudSaveDeviceTestApplication
extends GodotTapTapTestApplication

const TEST_DIRECTORY := "user://cloud_save_device_test"

var _device_store: TapCloudSaveDeviceLocalStore
var _runner: TapCloudSaveDeviceTestRunner


func _ready() -> void:
	super()
	_device_store = TapCloudSaveDeviceLocalStore.new()
	if not _device_store.prepare_for_launch():
		push_error("无法准备云存档真机测试目录")
		get_tree().quit(1)
		return
	if not FileAccess.file_exists(TapCloudSaveDeviceTestRunner.RESTART_STATE_PATH):
		if not _device_store.write_version(1):
			push_error("无法准备云存档真机测试 V1 存档")
			get_tree().quit(1)
			return
	add_child(_device_store)
	taptap_cloud_save_feature.deactivate()
	taptap_cloud_save_feature.configure(
		tap_tap_cloud_save_module,
		_device_store,
		TapCloudSaveSyncStore.new(TEST_DIRECTORY + "/sync"),
	)
	_runner = TapCloudSaveDeviceTestRunner.new()
	add_child(_runner)
	_runner.configure(taptap_cloud_save_feature, _device_store)
	if not taptap_access_feature.access_granted.is_connected(_on_device_access_granted):
		taptap_access_feature.access_granted.connect(_on_device_access_granted)
	if taptap_access_feature.get_state() == TapTapAccessFeature.State.ACCESS_GRANTED:
		_on_device_access_granted(taptap_access_feature.get_account())
	elif taptap_access_feature.get_state() == TapTapAccessFeature.State.WAITING_CONSENT:
		taptap_access_feature.set_privacy_accepted(true)
		var result := taptap_access_feature.initialize_sdk()
		if not result.accepted:
			push_error("真机测试无法初始化 TapSDK：%s %s" % [
				result.error_code, result.error_message
			])
			get_tree().quit(1)


func _on_device_access_granted(account: TapTapAccountSnapshot) -> void:
	if account == null:
		return
	if not taptap_cloud_save_feature.get_snapshot().active:
		taptap_cloud_save_feature.activate(account.open_id)
	_runner.start(account)
