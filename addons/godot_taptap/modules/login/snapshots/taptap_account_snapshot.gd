class_name TapTapAccountSnapshot
extends RefCounted

var open_id: String = ""
var union_id: String = ""
var name: String = ""
var avatar_url: String = ""
var scopes: PackedStringArray = PackedStringArray()


static func from_dictionary(data: Dictionary) -> TapTapAccountSnapshot:
	var snapshot := TapTapAccountSnapshot.new()
	snapshot.open_id = str(data.get("open_id", ""))
	snapshot.union_id = str(data.get("union_id", ""))
	snapshot.name = str(data.get("name", ""))
	snapshot.avatar_url = str(data.get("avatar_url", ""))
	var raw_scopes: Variant = data.get("scopes", [])
	if raw_scopes is Array:
		snapshot.scopes = PackedStringArray(raw_scopes)
	return snapshot
