extends GdUnitTestSuite

const EXPLICIT_ID := "11111111111111111111111111111111"


func test_empty_id_generates_valid_command_id() -> void:
	var command := GFCqrsTestCommand.new()

	assert_bool(GFId.is_valid(command.command_id)).is_true()


func test_explicit_id_is_preserved() -> void:
	var command := GFCqrsTestCommand.new(EXPLICIT_ID)

	assert_str(command.command_id).is_equal(EXPLICIT_ID)
