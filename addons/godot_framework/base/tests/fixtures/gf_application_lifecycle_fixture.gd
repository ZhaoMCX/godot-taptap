class_name GFApplicationLifecycleFixture
extends GFApplication

var ready_probe: GFFeatureReadyProbeFixture
var was_composed := false


func _init() -> void:
	ready_probe = GFFeatureReadyProbeFixture.new()
	ready_probe.name = "ReadyProbe"
	add_child(ready_probe)


func compose() -> void:
	ready_probe.configure()
	was_composed = true
