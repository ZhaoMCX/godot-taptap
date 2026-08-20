extends GdUnitTestSuite


func test_new_id_returns_unique_valid_values() -> void:
	var first := GFId.new_id()
	var second := GFId.new_id()

	assert_bool(GFId.is_valid(first)).is_true()
	assert_bool(GFId.is_valid(second)).is_true()
	assert_str(first).is_not_equal(second)


func test_invalid_ids_are_rejected() -> void:
	assert_bool(GFId.is_valid("")).is_false()
	assert_bool(GFId.is_valid("not-an-id")).is_false()
	assert_bool(GFId.is_valid("G".repeat(GFId.ID_STRING_LENGTH))).is_false()
