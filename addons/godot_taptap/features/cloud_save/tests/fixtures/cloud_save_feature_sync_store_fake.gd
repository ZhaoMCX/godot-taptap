class_name CloudSaveFeatureSyncStoreFake
extends TapCloudSaveSyncStore

var records: Dictionary = {}
var account_key := ""


func activate(key: String) -> void:
	account_key = key


func get_account_path() -> String:
	return "user://tap_cloud_save_feature_test"


func get_record(slot_id: String) -> Dictionary:
	var value: Variant = records.get(slot_id, {})
	return value.duplicate(true) if value is Dictionary else {}


func set_record(slot_id: String, record: Dictionary) -> bool:
	records[slot_id] = record.duplicate(true)
	return true


func erase_record(slot_id: String) -> bool:
	records.erase(slot_id)
	return true
