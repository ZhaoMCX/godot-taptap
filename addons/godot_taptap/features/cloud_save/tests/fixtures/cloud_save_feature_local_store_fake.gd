class_name CloudSaveFeatureLocalStoreFake
extends TapCloudSaveLocalStore

const UPLOAD_PATH := "user://tap_cloud_save_feature_upload.json"

var slots: Dictionary = {}
var imported_slots: Array[String] = []
var loaded_slots: Array[String] = []
var fail_import := false
var fail_load := false


func set_local(slot_id: String, fingerprint: String, summary: String = "本机序章") -> void:
	slots[slot_id] = TapCloudSaveLocalSnapshot.new(true, summary, 60, 100, fingerprint)


func get_slot_definitions() -> Array[TapCloudSaveSlotDefinition]:
	return [TapCloudSaveSlotDefinition.new("slot_1", "slot_1", "存档 1")]


func read_slot(slot_id: String) -> TapCloudSaveLocalSnapshot:
	return slots.get(slot_id, TapCloudSaveLocalSnapshot.new())


func prepare_upload(slot_id: String) -> TapCloudSaveUploadPayload:
	var local: TapCloudSaveLocalSnapshot = read_slot(slot_id)
	if not local.exists:
		return null
	var file := FileAccess.open(UPLOAD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"slot_id": slot_id, "fingerprint": local.fingerprint}))
	return TapCloudSaveUploadPayload.new(
		UPLOAD_PATH, "", local.summary, "test", local.playtime_seconds, local.fingerprint
	)


func import_download(slot_id: String, _downloaded_path: String) -> TapCloudSaveLocalResult:
	if fail_import:
		return TapCloudSaveLocalResult.failure(&"import_failed", "导入失败")
	imported_slots.append(slot_id)
	set_local(slot_id, "downloaded", "云端序章")
	return TapCloudSaveLocalResult.success_result()


func load_slot(slot_id: String) -> TapCloudSaveLocalResult:
	if fail_load:
		return TapCloudSaveLocalResult.failure(&"load_failed", "加载失败")
	if not read_slot(slot_id).exists:
		return TapCloudSaveLocalResult.failure(&"missing_local", "本机存档不存在")
	loaded_slots.append(slot_id)
	return TapCloudSaveLocalResult.success_result()
