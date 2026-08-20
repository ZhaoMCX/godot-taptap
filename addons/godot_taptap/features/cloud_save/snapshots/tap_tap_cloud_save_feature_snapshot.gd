class_name TapTapCloudSaveFeatureSnapshot
extends RefCounted

var active: bool
var cloud_confirmed: bool
var busy: bool
var selected_slot_id: String
var status_message: String
var slots: Array[TapTapCloudSaveSlotSnapshot]


func _init(
		is_active: bool,
		is_cloud_confirmed: bool,
		is_busy: bool,
		selection: String,
		message: String,
		current_slots: Array[TapTapCloudSaveSlotSnapshot],
) -> void:
	active = is_active
	cloud_confirmed = is_cloud_confirmed
	busy = is_busy
	selected_slot_id = selection
	status_message = message
	slots = current_slots.duplicate()
