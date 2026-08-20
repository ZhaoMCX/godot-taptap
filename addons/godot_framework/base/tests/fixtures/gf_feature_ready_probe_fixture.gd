class_name GFFeatureReadyProbeFixture
extends GFFeature

var was_configured_on_ready := false
var _was_configured := false


func configure() -> void:
	_was_configured = true


func _ready() -> void:
	was_configured_on_ready = _was_configured
