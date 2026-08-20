class_name SampleSaveCloudLocalStore
extends TapCloudSaveLocalStore

@export var sample_save_module: SampleSaveModule


func get_slot_definitions() -> Array[TapCloudSaveSlotDefinition]:
	return [
		TapCloudSaveSlotDefinition.new("slot_1", "slot_1", "存档 1"),
		TapCloudSaveSlotDefinition.new("slot_2", "slot_2", "存档 2"),
		TapCloudSaveSlotDefinition.new("slot_3", "slot_3", "存档 3"),
	]


func read_slot(slot_id: String) -> TapCloudSaveLocalSnapshot:
	return sample_save_module.read_slot(slot_id) if sample_save_module != null else TapCloudSaveLocalSnapshot.new()


func prepare_upload(slot_id: String) -> TapCloudSaveUploadPayload:
	return sample_save_module.prepare_upload(slot_id) if sample_save_module != null else null


func import_download(slot_id: String, downloaded_path: String) -> TapCloudSaveLocalResult:
	if sample_save_module == null:
		return TapCloudSaveLocalResult.failure(&"not_configured", "示例存档 Module 尚未配置")
	return sample_save_module.import_download(slot_id, downloaded_path)


func load_slot(slot_id: String) -> TapCloudSaveLocalResult:
	if sample_save_module == null:
		return TapCloudSaveLocalResult.failure(&"not_configured", "示例存档 Module 尚未配置")
	return sample_save_module.load_slot(slot_id)
