class_name GFApplication
extends Node

## Composition root for a Godot Framework application.
##
## Override [method compose] to resolve nodes and inject dependencies explicitly.
## Composition runs during [method Node._enter_tree], before child [method Node._ready]
## callbacks.


func _enter_tree() -> void:
	compose()


## Override in the concrete application. Keep cross-module behavior in features.
func compose() -> void:
	pass
