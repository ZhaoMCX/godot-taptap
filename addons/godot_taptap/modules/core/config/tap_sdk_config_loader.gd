class_name TapSdkConfigLoader
extends RefCounted

const DEFAULT_OVERRIDE_PATH := "res://override.cfg"
const TAP_SDK_SECTION := "tap_sdk"


func load_config(override_path: String = DEFAULT_OVERRIDE_PATH) -> TapSdkConfig:
	var config := TapSdkConfig.new()
	config.client_id = str(ProjectSettings.get_setting("tap_sdk/client_id", ""))
	config.client_token = str(ProjectSettings.get_setting("tap_sdk/client_token", ""))
	config.enable_debug_log = bool(ProjectSettings.get_setting("tap_sdk/enable_debug_log", false))

	var local_config := ConfigFile.new()
	if local_config.load(override_path) != OK:
		return config

	config.client_id = str(local_config.get_value(TAP_SDK_SECTION, "client_id", config.client_id))
	config.client_token = str(
		local_config.get_value(TAP_SDK_SECTION, "client_token", config.client_token)
	)
	config.enable_debug_log = bool(
		local_config.get_value(TAP_SDK_SECTION, "enable_debug_log", config.enable_debug_log)
	)
	return config
