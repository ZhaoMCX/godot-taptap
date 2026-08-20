class_name TapSdkAdapters
extends RefCounted

const NATIVE_SINGLETON := "TapTapSdkBridge"

var core: TapSdkCoreAdapter
var login: TapTapLoginAdapter
var compliance: TapTapComplianceAdapter
var cloud_save: TapTapCloudSaveAdapter


func _init(bridge: Object = null) -> void:
	var resolved_bridge := bridge
	if resolved_bridge == null and OS.get_name() == "Android" and Engine.has_singleton(NATIVE_SINGLETON):
		resolved_bridge = Engine.get_singleton(NATIVE_SINGLETON)
	core = TapSdkCoreAdapter.new(resolved_bridge)
	login = TapTapLoginAdapter.new(resolved_bridge, core)
	compliance = TapTapComplianceAdapter.new(resolved_bridge, core)
	cloud_save = TapTapCloudSaveAdapter.new(resolved_bridge, core)


func is_available() -> bool:
	return core.is_available()
