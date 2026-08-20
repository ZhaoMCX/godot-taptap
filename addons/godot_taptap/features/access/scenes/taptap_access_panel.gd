class_name TapTapAccessPanel
extends CenterContainer

const COMPLIANCE_CODES := [500, 1000, 1001, 1030, 1050, 1095, 1100, 1200, 9001, 9002, 42]

@onready var _environment_label: Label = %EnvironmentLabel
@onready var _consent_check: CheckButton = %ConsentCheck
@onready var _initialize_button: Button = %InitializeButton
@onready var _login_button: Button = %LoginButton
@onready var _logout_button: Button = %LogoutButton
@onready var _retry_button: Button = %RetryButton
@onready var _account_label: Label = %AccountLabel
@onready var _status_label: Label = %StatusLabel
@onready var _simulation_row: HBoxContainer = %SimulationRow
@onready var _code_option: OptionButton = %CodeOption
@onready var _simulate_button: Button = %SimulateButton

var _feature: TapTapAccessFeature
var _simulator_bridge: TapSdkSimulatorBridge
var _controls_bound := false


func configure(feature: TapTapAccessFeature, simulator_bridge: TapSdkSimulatorBridge = null) -> void:
	_feature = feature
	_simulator_bridge = simulator_bridge
	if is_node_ready():
		_update_environment()
		_bind_feature()


func _ready() -> void:
	for code: int in COMPLIANCE_CODES:
		_code_option.add_item(str(code), code)
	_update_environment()
	_bind_feature()


func _update_environment() -> void:
	_environment_label.text = (
		"桌面 Debug 模拟桥接（不会调用真实 TapSDK）"
		if _simulator_bridge != null
		else "Android 原生 TapSDK 桥接"
	)
	_simulation_row.visible = _simulator_bridge != null


func _bind_feature() -> void:
	if _feature == null or _controls_bound:
		return
	_consent_check.toggled.connect(_on_consent_toggled)
	_initialize_button.pressed.connect(_feature.initialize_sdk)
	_login_button.pressed.connect(_feature.login)
	_logout_button.pressed.connect(_feature.logout)
	_retry_button.pressed.connect(_feature.retry)
	_simulate_button.pressed.connect(_on_simulate_pressed)
	_feature.state_changed.connect(_on_state_changed)
	_feature.account_changed.connect(_on_account_changed)
	_controls_bound = true
	_on_account_changed(_feature.get_account())
	_on_state_changed(_feature.get_state(), _feature.get_status_message())


func _on_consent_toggled(accepted: bool) -> void:
	_feature.set_privacy_accepted(accepted)


func _on_simulate_pressed() -> void:
	if _simulator_bridge == null or _feature == null:
		return
	var selected_id := _code_option.get_selected_id()
	_simulator_bridge.set_next_compliance_code(selected_id)
	_feature.recheck_compliance()


func _on_state_changed(state: TapTapAccessFeature.State, message: String) -> void:
	_status_label.text = "状态：%s\n%s" % [TapTapAccessFeature.State.keys()[state], message]
	_consent_check.disabled = state not in [
		TapTapAccessFeature.State.WAITING_CONSENT,
		TapTapAccessFeature.State.READY_TO_INITIALIZE,
	]
	_initialize_button.disabled = state != TapTapAccessFeature.State.READY_TO_INITIALIZE
	_login_button.disabled = state != TapTapAccessFeature.State.SIGNED_OUT
	_logout_button.disabled = _feature.get_account() == null
	_retry_button.disabled = state != TapTapAccessFeature.State.RETRYABLE_ERROR
	_simulate_button.disabled = _feature.get_account() == null


func _on_account_changed(account: TapTapAccountSnapshot) -> void:
	if account == null:
		_account_label.text = "账号：未登录"
	else:
		_account_label.text = "账号：%s\nOpen ID：%s" % [account.name, account.open_id]
	_logout_button.disabled = account == null
	_simulate_button.disabled = account == null
