class_name GFMessageValidator
extends RefCounted

const DEFAULT_MAX_DEPTH := 32


static func is_valid_command(command: GFCommand) -> bool:
	return (
		command != null
		and GFId.is_valid(command.command_id)
		and not command.get_message_type().is_empty()
		and is_network_safe(command.to_payload())
	)


static func is_valid_event(event: GFEvent) -> bool:
	return (
		event != null
		and GFId.is_valid(event.event_id)
		and (event.causation_id.is_empty() or GFId.is_valid(event.causation_id))
		and not event.get_message_type().is_empty()
		and is_network_safe(event.to_payload())
	)


## Returns true when a value can safely cross a future Godot network adapter.
## NodePath is intentionally excluded: dynamic entities must use stable IDs.
static func is_network_safe(value: Variant, max_depth: int = DEFAULT_MAX_DEPTH) -> bool:
	if max_depth < 0:
		return false

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I:
			return true
		TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_TRANSFORM2D:
			return true
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION:
			return true
		TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_COLOR:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return true
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return true
		TYPE_PACKED_COLOR_ARRAY:
			return true
		TYPE_ARRAY:
			for item in value:
				if not is_network_safe(item, max_depth - 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not is_network_safe(key, max_depth - 1):
					return false
				if not is_network_safe(value[key], max_depth - 1):
					return false
			return true
		_:
			return false
