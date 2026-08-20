extends GdUnitTestSuite

const COMMAND_ID := "11111111111111111111111111111111"


func test_success_discards_error_details_and_preserves_causation() -> void:
	var event := GFCommandCompletedEvent.new(
		COMMAND_ID,
		true,
		&"unexpected",
		"unexpected",
	)

	assert_str(event.causation_id).is_equal(COMMAND_ID)
	assert_bool(event.succeeded).is_true()
	assert_str(event.error_code).is_empty()
	assert_str(event.error_message).is_empty()
	assert_dict(event.to_payload()).contains_key_value("succeeded", true)


func test_failure_preserves_error_details() -> void:
	var event := GFCommandCompletedEvent.new(COMMAND_ID, false, &"failed", "Command failed.")

	assert_bool(event.succeeded).is_false()
	assert_str(event.error_code).is_equal(&"failed")
	assert_str(event.error_message).is_equal("Command failed.")
