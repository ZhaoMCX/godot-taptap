class_name TapCloudSaveLocalStore
extends Node

## Host boundary used by the reusable cloud-save feature.
##
## Games override these methods and keep their save format outside this plugin.


func get_slot_definitions() -> Array[TapCloudSaveSlotDefinition]:
	return []


func read_slot(_slot_id: String) -> TapCloudSaveLocalSnapshot:
	return TapCloudSaveLocalSnapshot.new()


func prepare_upload(_slot_id: String) -> TapCloudSaveUploadPayload:
	return null


func import_download(_slot_id: String, _downloaded_path: String) -> TapCloudSaveLocalResult:
	return TapCloudSaveLocalResult.failure(&"not_implemented", "宿主尚未实现云存档导入")


func load_slot(_slot_id: String) -> TapCloudSaveLocalResult:
	return TapCloudSaveLocalResult.failure(&"not_implemented", "宿主尚未实现存档加载")
