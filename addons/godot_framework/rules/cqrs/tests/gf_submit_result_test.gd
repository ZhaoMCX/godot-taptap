extends GdUnitTestSuite

const COMMAND_ID := "11111111111111111111111111111111"


func test_accepted_result_discards_error_details() -> void:
	var result := GFSubmitResult.new(true, COMMAND_ID, &"unexpected", "unexpected")

	assert_bool(result.accepted).is_true()
	assert_str(result.command_id).is_equal(COMMAND_ID)
	assert_str(result.error_code).is_empty()
	assert_str(result.error_message).is_empty()


func test_rejected_result_preserves_error_details() -> void:
	var result := GFSubmitResult.rejected_result(COMMAND_ID, &"invalid", "Invalid command.")

	assert_bool(result.accepted).is_false()
	assert_str(result.command_id).is_equal(COMMAND_ID)
	assert_str(result.error_code).is_equal(&"invalid")
	assert_str(result.error_message).is_equal("Invalid command.")
