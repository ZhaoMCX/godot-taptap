extends GdUnitTestSuite

const CAUSATION_ID := "11111111111111111111111111111111"
const EXPLICIT_EVENT_ID := "22222222222222222222222222222222"


func test_empty_id_generates_valid_event_id_and_preserves_causation() -> void:
	var event := GFCqrsTestEvent.new(CAUSATION_ID)

	assert_bool(GFId.is_valid(event.event_id)).is_true()
	assert_str(event.causation_id).is_equal(CAUSATION_ID)


func test_explicit_event_id_is_preserved() -> void:
	var event := GFCqrsTestEvent.new(CAUSATION_ID, EXPLICIT_EVENT_ID)

	assert_str(event.event_id).is_equal(EXPLICIT_EVENT_ID)
