class_name GFId
extends RefCounted

const ID_BYTE_LENGTH := 16
const ID_STRING_LENGTH := ID_BYTE_LENGTH * 2
const HEX_DIGITS := "0123456789abcdef"


## Returns an opaque 128-bit lowercase hexadecimal identifier.
static func new_id() -> String:
	return Crypto.new().generate_random_bytes(ID_BYTE_LENGTH).hex_encode()


static func is_valid(value: String) -> bool:
	if value.length() != ID_STRING_LENGTH:
		return false

	for character in value:
		if not HEX_DIGITS.contains(character):
			return false

	return true
