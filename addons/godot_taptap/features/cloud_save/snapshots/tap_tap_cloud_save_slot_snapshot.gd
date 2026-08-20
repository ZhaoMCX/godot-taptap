class_name TapTapCloudSaveSlotSnapshot
extends RefCounted

enum Status {
	EMPTY,
	LOCAL_ONLY,
	CLOUD_ONLY,
	SYNCED,
	LOCAL_CHANGED,
	REMOTE_CHANGED,
	CONFLICT,
	UNCONFIRMED,
	ERROR,
}

var definition: TapCloudSaveSlotDefinition
var local: TapCloudSaveLocalSnapshot
var remote: TapCloudSaveArchiveSnapshot
var status: Status
var cover_path: String
var cover_loading: bool
var error_message: String


func _init(
		slot_definition: TapCloudSaveSlotDefinition,
		local_snapshot: TapCloudSaveLocalSnapshot,
		remote_snapshot: TapCloudSaveArchiveSnapshot,
		current_status: Status,
		cached_cover_path: String = "",
		is_cover_loading: bool = false,
		error: String = "",
) -> void:
	definition = slot_definition
	local = local_snapshot
	remote = remote_snapshot
	status = current_status
	cover_path = cached_cover_path
	cover_loading = is_cover_loading
	error_message = error
