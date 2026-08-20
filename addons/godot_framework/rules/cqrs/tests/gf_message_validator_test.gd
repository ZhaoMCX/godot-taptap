extends GdUnitTestSuite

const VALID_COMMAND_ID := "11111111111111111111111111111111"
const VALID_EVENT_ID := "22222222222222222222222222222222"


func test_accepts_nested_network_safe_payload() -> void:
	var payload := {
		"position": Vector3(1.0, 2.0, 3.0),
		"tags": [&"player", &"alive"],
		"stats": {"health": 100, "speed": 4.5},
	}

	assert_bool(GFMessageValidator.is_network_safe(payload)).is_true()


func test_rejects_object_payload() -> void:
	var node := auto_free(Node.new()) as Node
	var command := GFCqrsTestCommand.new(
		VALID_COMMAND_ID,
		GFCqrsTestCommand.DEFAULT_TYPE,
		{"object": node},
	)

	assert_bool(GFMessageValidator.is_valid_command(command)).is_false()


func test_rejects_node_path_identity() -> void:
	assert_bool(GFMessageValidator.is_network_safe(NodePath("/root/Player"))).is_false()


func test_rejects_values_beyond_maximum_depth() -> void:
	var payload: Variant = "leaf"
	for _index in range(GFMessageValidator.DEFAULT_MAX_DEPTH + 2):
		payload = [payload]

	assert_bool(GFMessageValidator.is_network_safe(payload)).is_false()


func test_validates_command_contract() -> void:
	assert_bool(GFMessageValidator.is_valid_command(GFCqrsTestCommand.new(VALID_COMMAND_ID))).is_true()
	assert_bool(GFMessageValidator.is_valid_command(null)).is_false()
	assert_bool(GFMessageValidator.is_valid_command(GFCqrsTestCommand.new("invalid"))).is_false()
	assert_bool(
		GFMessageValidator.is_valid_command(GFCqrsTestCommand.new(VALID_COMMAND_ID, &""))
	).is_false()


func test_validates_event_contract() -> void:
	assert_bool(
		GFMessageValidator.is_valid_event(
			GFCqrsTestEvent.new(VALID_COMMAND_ID, VALID_EVENT_ID)
		)
	).is_true()
	assert_bool(GFMessageValidator.is_valid_event(null)).is_false()
	assert_bool(
		GFMessageValidator.is_valid_event(GFCqrsTestEvent.new(VALID_COMMAND_ID, "invalid"))
	).is_false()
	assert_bool(
		GFMessageValidator.is_valid_event(GFCqrsTestEvent.new("invalid", VALID_EVENT_ID))
	).is_false()
	assert_bool(
		GFMessageValidator.is_valid_event(
			GFCqrsTestEvent.new(VALID_COMMAND_ID, VALID_EVENT_ID, &"")
		)
	).is_false()
