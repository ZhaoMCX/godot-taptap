class_name GFApplication
extends Node

## The single active composition root for one Godot Framework game run.
##
## Override [method compose] to validate scene-declared nodes and inject dependencies
## explicitly. Keep gameplay behavior and owned content in features or modules.
## Composition runs during [method Node._ready], after scene-declared child references
## have been resolved.


func _ready() -> void:
	compose()


## Override in the concrete application. Keep cross-module behavior in features.
func compose() -> void:
	pass
