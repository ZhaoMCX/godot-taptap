@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const VERSION := "4.10.8"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(
			_platform: EditorExportPlatform,
			debug: bool
	) -> PackedStringArray:
		if debug:
			return PackedStringArray(["godot_taptap/tools/taptap/bin/debug/GodotTapTap.debug.aar"])
		return PackedStringArray(["godot_taptap/tools/taptap/bin/release/GodotTapTap.release.aar"])

	func _get_android_dependencies(
			_platform: EditorExportPlatform,
			_debug: bool
	) -> PackedStringArray:
		return PackedStringArray([
			"com.taptap.sdk:tap-core:%s" % VERSION,
			"com.taptap.sdk:tap-login:%s" % VERSION,
			"com.taptap.sdk:tap-compliance:%s" % VERSION,
			"com.taptap.sdk:tap-cloudsave:%s" % VERSION,
		])

	func _get_android_dependencies_maven_repos(
			_platform: EditorExportPlatform,
			_debug: bool
	) -> PackedStringArray:
		return PackedStringArray(["https://repo.maven.apache.org/maven2"])

	func _get_name() -> String:
		return "Godot TapTap"
