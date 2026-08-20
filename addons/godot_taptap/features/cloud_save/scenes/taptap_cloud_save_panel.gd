class_name TapTapCloudSavePanel
extends Control

signal logout_requested

@onready var _slot_list: VBoxContainer = %SlotList
@onready var _refresh_button: Button = %RefreshButton
@onready var _logout_button: Button = %LogoutButton
@onready var _title_label: Label = %SlotTitleLabel
@onready var _status_badge: Label = %StatusBadge
@onready var _cover: TextureRect = %Cover
@onready var _summary_label: Label = %SummaryLabel
@onready var _local_label: Label = %LocalLabel
@onready var _cloud_label: Label = %CloudLabel
@onready var _message_label: Label = %MessageLabel
@onready var _primary_button: Button = %PrimaryButton
@onready var _use_cloud_button: Button = %UseCloudButton
@onready var _keep_local_button: Button = %KeepLocalButton
@onready var _delete_button: Button = %DeleteButton
@onready var _confirmation: ConfirmationDialog = %ConfirmationDialog

var _feature: TapTapCloudSaveFeature
var _snapshot: TapTapCloudSaveFeatureSnapshot
var _selected: TapTapCloudSaveSlotSnapshot
var _confirmed_action: Callable
var _bound := false


func configure(feature: TapTapCloudSaveFeature) -> void:
	if _feature != null and _feature.state_changed.is_connected(_on_state_changed):
		_feature.state_changed.disconnect(_on_state_changed)
	_feature = feature
	if is_node_ready():
		_bind()


func _ready() -> void:
	_bind()


func _bind() -> void:
	if _feature == null:
		return
	if not _bound:
		_refresh_button.pressed.connect(_feature.refresh)
		_logout_button.pressed.connect(_on_logout_pressed)
		_primary_button.pressed.connect(_on_primary_pressed)
		_use_cloud_button.pressed.connect(_on_use_cloud_pressed)
		_keep_local_button.pressed.connect(_on_keep_local_pressed)
		_delete_button.pressed.connect(_on_delete_pressed)
		_confirmation.confirmed.connect(_on_confirmed)
		_bound = true
	if not _feature.state_changed.is_connected(_on_state_changed):
		_feature.state_changed.connect(_on_state_changed)
	_on_state_changed(_feature.get_snapshot())


func _on_state_changed(snapshot: TapTapCloudSaveFeatureSnapshot) -> void:
	_snapshot = snapshot
	_selected = null
	for child: Node in _slot_list.get_children():
		child.queue_free()
	for slot: TapTapCloudSaveSlotSnapshot in snapshot.slots:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.text = "%s\n%s" % [slot.definition.display_name, _status_text(slot.status)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = slot.definition.slot_id == snapshot.selected_slot_id
		button.pressed.connect(_feature.select_slot.bind(slot.definition.slot_id))
		_slot_list.add_child(button)
		if button.button_pressed:
			_selected = slot
	_refresh_button.disabled = snapshot.busy
	_logout_button.disabled = snapshot.busy
	_message_label.text = snapshot.status_message
	_render_details()


func _render_details() -> void:
	if _selected == null:
		_title_label.text = "尚未配置存档槽位"
		_status_badge.text = "需要宿主提供 TapCloudSaveLocalStore"
		_summary_label.text = "当前插件界面可以运行，但没有可显示的游戏存档。"
		_local_label.text = ""
		_cloud_label.text = ""
		_primary_button.visible = false
		_use_cloud_button.visible = false
		_keep_local_button.visible = false
		_delete_button.visible = false
		_cover.texture = null
		return
	_title_label.text = _selected.definition.display_name
	_status_badge.text = _status_text(_selected.status)
	_summary_label.text = _summary_text(_selected)
	_local_label.text = _version_text("本机", _selected.local)
	_cloud_label.text = _remote_text(_selected.remote)
	_load_cover(_selected.cover_path)
	var conflict := _selected.status == TapTapCloudSaveSlotSnapshot.Status.CONFLICT
	_use_cloud_button.visible = conflict and _selected.remote != null
	_keep_local_button.visible = conflict and _selected.local.exists
	_primary_button.visible = not conflict
	_primary_button.text = _primary_text(_selected)
	_primary_button.disabled = _snapshot.busy or not _can_primary(_selected)
	_use_cloud_button.disabled = _snapshot.busy
	_keep_local_button.disabled = _snapshot.busy
	_delete_button.visible = _selected.remote != null
	_delete_button.disabled = _snapshot.busy or not _snapshot.cloud_confirmed


func _on_primary_pressed() -> void:
	if _selected == null:
		return
	match _selected.status:
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY:
			_feature.request_upload(_selected.definition.slot_id)
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED:
			_confirm(
				"上传后将覆盖现有云备份，但会保留本机存档。",
				func() -> void: _feature.request_upload(_selected.definition.slot_id),
			)
		TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY, TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED:
			_confirm_cloud_load()
		TapTapCloudSaveSlotSnapshot.Status.SYNCED:
			_feature.request_load(_selected.definition.slot_id)
		TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED:
			_confirm(
				"云端状态尚未确认，将只载入当前本机存档。",
				func() -> void: _feature.request_load(_selected.definition.slot_id),
			)


func _on_use_cloud_pressed() -> void:
	_confirm_cloud_load()


func _on_keep_local_pressed() -> void:
	if _selected == null:
		return
	_confirm(
		"将保留本机版本并覆盖当前云备份。此操作无法自动撤销。",
		func() -> void: _feature.resolve_conflict(_selected.definition.slot_id, false),
	)


func _on_delete_pressed() -> void:
	if _selected == null:
		return
	_confirm(
		"只删除该槽位的云备份，本机存档会保留。",
		func() -> void: _feature.request_delete(_selected.definition.slot_id),
	)


func _on_logout_pressed() -> void:
	_confirm(
		"将退出当前 TapTap 账号并返回登录页面。",
		func() -> void: logout_requested.emit(),
	)


func _confirm_cloud_load() -> void:
	if _selected == null:
		return
	_confirm(
		"云端版本将替换本机槽位，并在下载成功后立即载入。",
		func() -> void: _feature.resolve_conflict(_selected.definition.slot_id, true),
	)


func _confirm(message: String, action: Callable) -> void:
	_confirmed_action = action
	_confirmation.dialog_text = message
	_confirmation.popup_centered(Vector2i(520, 220))


func _on_confirmed() -> void:
	if _confirmed_action.is_null():
		return
	var action := _confirmed_action
	_confirmed_action = Callable()
	action.call()


func _can_primary(slot: TapTapCloudSaveSlotSnapshot) -> bool:
	match slot.status:
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY, TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY, TapTapCloudSaveSlotSnapshot.Status.SYNCED, TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED, TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED:
			return true
		TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED:
			return slot.local.exists
	return false


func _primary_text(slot: TapTapCloudSaveSlotSnapshot) -> String:
	match slot.status:
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY:
			return "创建云备份"
		TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY, TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED:
			return "载入云端存档"
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED:
			return "上传到云端"
		TapTapCloudSaveSlotSnapshot.Status.SYNCED:
			return "载入存档"
		TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED:
			return "离线载入本机存档"
		TapTapCloudSaveSlotSnapshot.Status.ERROR:
			return "槽位异常"
	return "暂无可用操作"


func _status_text(status: TapTapCloudSaveSlotSnapshot.Status) -> String:
	var labels := {
		TapTapCloudSaveSlotSnapshot.Status.EMPTY: "空槽位",
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_ONLY: "仅本机",
		TapTapCloudSaveSlotSnapshot.Status.CLOUD_ONLY: "仅云端",
		TapTapCloudSaveSlotSnapshot.Status.SYNCED: "已同步",
		TapTapCloudSaveSlotSnapshot.Status.LOCAL_CHANGED: "本机有更新",
		TapTapCloudSaveSlotSnapshot.Status.REMOTE_CHANGED: "云端有更新",
		TapTapCloudSaveSlotSnapshot.Status.CONFLICT: "需要选择版本",
		TapTapCloudSaveSlotSnapshot.Status.UNCONFIRMED: "云端状态未确认",
		TapTapCloudSaveSlotSnapshot.Status.ERROR: "异常",
	}
	return str(labels.get(status, "未知"))


func _summary_text(slot: TapTapCloudSaveSlotSnapshot) -> String:
	if not slot.error_message.is_empty():
		return slot.error_message
	if slot.remote != null and not slot.remote.summary.is_empty():
		return slot.remote.summary
	if slot.local.exists:
		return slot.local.summary
	return "该槽位还没有存档。"


func _version_text(label: String, local: TapCloudSaveLocalSnapshot) -> String:
	if local == null or not local.exists:
		return "%s：无存档" % label
	return "%s：%s\n游玩时长：%s　更新时间：%s" % [
		label,
		local.summary,
		_format_playtime(local.playtime_seconds),
		_format_time(local.modified_time),
	]


func _remote_text(remote: TapCloudSaveArchiveSnapshot) -> String:
	if remote == null:
		return "云端：无备份"
	return "云端：%s\n游玩时长：%s　更新时间：%s" % [
		remote.summary,
		_format_playtime(remote.playtime_seconds),
		_format_time(remote.modified_time),
	]


func _format_playtime(seconds: int) -> String:
	return "%d 小时 %02d 分" % [seconds / 3600, (seconds % 3600) / 60]


func _format_time(timestamp: int) -> String:
	return "未知" if timestamp <= 0 else Time.get_datetime_string_from_unix_time(timestamp, true)


func _load_cover(path: String) -> void:
	_cover.texture = null
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) == OK:
		_cover.texture = ImageTexture.create_from_image(image)
