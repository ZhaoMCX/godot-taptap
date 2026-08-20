extends GdUnitTestSuite

const CLIENT_ID_SETTING := "tap_sdk/client_id"
const CLIENT_TOKEN_SETTING := "tap_sdk/client_token"
const DEBUG_LOG_SETTING := "tap_sdk/enable_debug_log"
const TEMP_CONFIG_PATH := "user://tap_sdk_config_loader_test.cfg"

var _original_settings: Dictionary[String, Variant] = {}
var _original_setting_presence: Dictionary[String, bool] = {}


func before() -> void:
	for setting: String in [CLIENT_ID_SETTING, CLIENT_TOKEN_SETTING, DEBUG_LOG_SETTING]:
		_original_setting_presence[setting] = ProjectSettings.has_setting(setting)
		_original_settings[setting] = ProjectSettings.get_setting(setting)


func after() -> void:
	for setting: String in [CLIENT_ID_SETTING, CLIENT_TOKEN_SETTING, DEBUG_LOG_SETTING]:
		if _original_setting_presence[setting]:
			ProjectSettings.set_setting(setting, _original_settings[setting])
		else:
			ProjectSettings.set_setting(setting, null)
	if FileAccess.file_exists(TEMP_CONFIG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_CONFIG_PATH))


func test_load_config_uses_project_settings_without_local_override() -> void:
	ProjectSettings.set_setting(CLIENT_ID_SETTING, "project-client-id")
	ProjectSettings.set_setting(CLIENT_TOKEN_SETTING, "project-client-token")
	ProjectSettings.set_setting(DEBUG_LOG_SETTING, false)
	var config := TapSdkConfigLoader.new().load_config("res://missing_tap_sdk_override.cfg")
	assert_str(config.client_id).is_equal("project-client-id")
	assert_str(config.client_token).is_equal("project-client-token")
	assert_bool(config.enable_debug_log).is_false()


func test_load_config_applies_exported_local_override() -> void:
	ProjectSettings.set_setting(CLIENT_ID_SETTING, "")
	ProjectSettings.set_setting(CLIENT_TOKEN_SETTING, "")
	ProjectSettings.set_setting(DEBUG_LOG_SETTING, false)
	var local_config := ConfigFile.new()
	local_config.set_value("tap_sdk", "client_id", "local-client-id")
	local_config.set_value("tap_sdk", "client_token", "local-client-token")
	local_config.set_value("tap_sdk", "enable_debug_log", true)
	assert_int(local_config.save(TEMP_CONFIG_PATH)).is_equal(OK)
	var config := TapSdkConfigLoader.new().load_config(TEMP_CONFIG_PATH)
	assert_str(config.client_id).is_equal("local-client-id")
	assert_str(config.client_token).is_equal("local-client-token")
	assert_bool(config.enable_debug_log).is_true()


func test_config_validation_rejects_missing_credentials() -> void:
	var config := TapSdkConfig.new()
	assert_int(config.validate().code).is_equal(TapSdkError.Code.INVALID_CONFIG)
	config.client_id = "client-id"
	assert_int(config.validate().code).is_equal(TapSdkError.Code.INVALID_CONFIG)
	config.client_token = "client-token"
	assert_object(config.validate()).is_null()
