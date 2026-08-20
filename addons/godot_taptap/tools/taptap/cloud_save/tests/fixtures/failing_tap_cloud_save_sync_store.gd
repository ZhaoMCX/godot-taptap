class_name FailingTapCloudSaveSyncStore
extends TapCloudSaveSyncStore

var fail_replace := false


func _replace_file(path: String, temporary_path: String) -> bool:
	if not fail_replace:
		return super(path, temporary_path)
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	return false
