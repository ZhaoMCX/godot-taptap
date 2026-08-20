class_name TapSdkCoreModule
extends GFModule

signal sdk_initialized(event: TapSdkInitializedEvent)
signal command_completed(event: GFCommandCompletedEvent)

enum State {
	UNINITIALIZED,
	INITIALIZING,
	READY,
	FAILED,
}

var _adapter: TapSdkCoreAdapter
var _config: TapSdkConfig
var _state: State = State.UNINITIALIZED
var _error_message := ""
var _pending_command_id := ""


func configure(adapter: TapSdkCoreAdapter, config: TapSdkConfig) -> void:
	_disconnect_adapter()
	_adapter = adapter
	_config = config
	if _adapter != null:
		_adapter.initialized.connect(_on_initialized)
		_adapter.initialization_failed.connect(_on_initialization_failed)


func submit_initialize(command: TapSdkInitializeCommand) -> GFSubmitResult:
	var validation := _validate_command(command)
	if validation != null:
		return validation
	if not _pending_command_id.is_empty():
		return GFSubmitResult.rejected_result(command.command_id, &"busy", "TapSDK 正在初始化")
	if _adapter == null or _config == null:
		return GFSubmitResult.rejected_result(
			command.command_id, &"not_configured", "TapSDK Core Module 尚未配置"
		)

	var consent := TapPrivacyConsent.new()
	consent.privacy_policy_accepted = command.privacy_policy_accepted
	_pending_command_id = command.command_id
	_state = State.INITIALIZING
	_error_message = ""
	var result := _adapter.initialize(_config, consent)
	if not result.accepted:
		_pending_command_id = ""
		_state = State.FAILED
		_error_message = result.error.message
		return GFSubmitResult.rejected_result(
			command.command_id, _error_code(result.error), result.error.message
		)

	return GFSubmitResult.accepted_result(command.command_id)


func get_snapshot() -> TapSdkStateSnapshot:
	return TapSdkStateSnapshot.new(_state, _error_message)


func _exit_tree() -> void:
	_disconnect_adapter()


func _on_initialized() -> void:
	_state = State.READY
	_error_message = ""
	var command_id := _pending_command_id
	_pending_command_id = ""
	sdk_initialized.emit(TapSdkInitializedEvent.new(command_id))
	command_completed.emit(GFCommandCompletedEvent.new(command_id, true))


func _on_initialization_failed(error: TapSdkError) -> void:
	_state = State.FAILED
	_error_message = error.message
	var command_id := _pending_command_id
	_pending_command_id = ""
	command_completed.emit(
		GFCommandCompletedEvent.new(command_id, false, _error_code(error), error.message)
	)


func _validate_command(command: TapSdkInitializeCommand) -> GFSubmitResult:
	if not GFMessageValidator.is_valid_command(command):
		var command_id := "" if command == null else command.command_id
		return GFSubmitResult.rejected_result(
			command_id, &"invalid_command", "初始化命令不是可安全传输的 GF Command"
		)
	return null


func _disconnect_adapter() -> void:
	if _adapter == null:
		return
	if _adapter.initialized.is_connected(_on_initialized):
		_adapter.initialized.disconnect(_on_initialized)
	if _adapter.initialization_failed.is_connected(_on_initialization_failed):
		_adapter.initialization_failed.disconnect(_on_initialization_failed)


func _error_code(error: TapSdkError) -> StringName:
	return StringName(TapSdkError.Code.keys()[error.code].to_lower())
