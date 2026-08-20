class_name TapTapApplication
extends GFApplication

## Standalone TapTap composition root.
##
## GF projects can inherit this application and add their own features. Projects
## that do not provide a separate composition root can run the bundled scene
## directly.

@export var tap_sdk_core_module: TapSdkCoreModule
@export var tap_tap_login_module: TapTapLoginModule
@export var tap_tap_compliance_module: TapTapComplianceModule
@export var tap_tap_cloud_save_module: TapTapCloudSaveModule
@export var taptap_access_feature: TapTapAccessFeature
@export var taptap_access_panel: TapTapAccessPanel
@export var taptap_cloud_save_feature: TapTapCloudSaveFeature
@export var taptap_cloud_save_panel: TapTapCloudSavePanel
@export var cloud_save_local_store: TapCloudSaveLocalStore

var _tap_sdk_adapters: TapSdkAdapters
var _tap_sdk_config_loader := TapSdkConfigLoader.new()


func _enter_tree() -> void:
	# Exported child-node references are resolved after the scene enters the tree.
	# Compose in _ready() once those references are available.
	pass


func _ready() -> void:
	compose()


func compose() -> void:
	var simulator_bridge: TapSdkSimulatorBridge
	if OS.get_name() != "Android" and OS.is_debug_build():
		simulator_bridge = TapSdkSimulatorBridge.new()
	_tap_sdk_adapters = TapSdkAdapters.new(simulator_bridge)
	if not _validate_scene_dependencies():
		return

	var config := _load_tap_sdk_config()
	if simulator_bridge != null and config.validate() != null:
		config.client_id = "demo-client-id"
		config.client_token = "demo-client-token"

	tap_sdk_core_module.configure(_tap_sdk_adapters.core, config)
	tap_tap_login_module.configure(_tap_sdk_adapters.login)
	tap_tap_compliance_module.configure(_tap_sdk_adapters.compliance)
	tap_tap_cloud_save_module.configure(_tap_sdk_adapters.cloud_save)
	taptap_access_feature.configure(
		tap_sdk_core_module,
		tap_tap_login_module,
		tap_tap_compliance_module,
	)
	taptap_access_panel.configure(taptap_access_feature, simulator_bridge)
	taptap_cloud_save_feature.configure(tap_tap_cloud_save_module, cloud_save_local_store)
	taptap_cloud_save_panel.configure(taptap_cloud_save_feature)
	if not taptap_access_feature.access_granted.is_connected(_on_access_granted):
		taptap_access_feature.access_granted.connect(_on_access_granted)
	if not taptap_access_feature.account_changed.is_connected(_on_account_changed):
		taptap_access_feature.account_changed.connect(_on_account_changed)
	if not taptap_access_feature.state_changed.is_connected(_on_access_state_changed):
		taptap_access_feature.state_changed.connect(_on_access_state_changed)
	if not taptap_cloud_save_panel.logout_requested.is_connected(_on_logout_requested):
		taptap_cloud_save_panel.logout_requested.connect(_on_logout_requested)
	taptap_cloud_save_panel.hide()


func get_taptap_access_feature() -> TapTapAccessFeature:
	return taptap_access_feature


func get_taptap_cloud_save_feature() -> TapTapCloudSaveFeature:
	return taptap_cloud_save_feature


func _validate_scene_dependencies() -> bool:
	var valid := true
	if tap_sdk_core_module == null:
		push_error("TapTapApplication 缺少 tap_sdk_core_module 场景依赖")
		valid = false
	if tap_tap_login_module == null:
		push_error("TapTapApplication 缺少 tap_tap_login_module 场景依赖")
		valid = false
	if tap_tap_compliance_module == null:
		push_error("TapTapApplication 缺少 tap_tap_compliance_module 场景依赖")
		valid = false
	if tap_tap_cloud_save_module == null:
		push_error("TapTapApplication 缺少 tap_tap_cloud_save_module 场景依赖")
		valid = false
	if taptap_access_feature == null:
		push_error("TapTapApplication 缺少 taptap_access_feature 场景依赖")
		valid = false
	if taptap_access_panel == null:
		push_error("TapTapApplication 缺少 taptap_access_panel 场景依赖")
		valid = false
	if taptap_cloud_save_feature == null:
		push_error("TapTapApplication 缺少 taptap_cloud_save_feature 场景依赖")
		valid = false
	if taptap_cloud_save_panel == null:
		push_error("TapTapApplication 缺少 taptap_cloud_save_panel 场景依赖")
		valid = false
	if cloud_save_local_store == null:
		push_error("TapTapApplication 缺少 cloud_save_local_store 场景依赖")
		valid = false
	return valid


func _load_tap_sdk_config() -> TapSdkConfig:
	var config: TapSdkConfig = _tap_sdk_config_loader.load_config()
	config.show_switch_account = true
	return config


func _on_access_granted(account: TapTapAccountSnapshot) -> void:
	if account == null:
		return
	taptap_access_panel.hide()
	taptap_cloud_save_panel.show()
	taptap_cloud_save_feature.activate(account.open_id)


func _on_account_changed(account: TapTapAccountSnapshot) -> void:
	if account != null:
		return
	taptap_cloud_save_feature.deactivate()
	taptap_cloud_save_panel.hide()
	taptap_access_panel.show()


func _on_access_state_changed(state: TapTapAccessFeature.State, _message: String) -> void:
	if state == TapTapAccessFeature.State.ACCESS_GRANTED:
		return
	if taptap_cloud_save_feature.get_snapshot().active:
		taptap_cloud_save_feature.deactivate()
		taptap_cloud_save_panel.hide()
		taptap_access_panel.show()


func _on_logout_requested() -> void:
	taptap_access_feature.logout()
