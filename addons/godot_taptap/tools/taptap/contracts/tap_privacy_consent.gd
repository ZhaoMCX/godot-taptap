class_name TapPrivacyConsent
extends RefCounted

var privacy_policy_accepted: bool = false


func to_dictionary() -> Dictionary:
	return {
		"privacy_policy_accepted": privacy_policy_accepted,
	}
