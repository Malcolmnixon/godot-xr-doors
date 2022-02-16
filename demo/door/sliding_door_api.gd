class_name SlidingDoorApi
extends DoorApi


##
## Sliding Door API script
##
## @desc:
##     This script exposes the public API for sliding doors. It contains all the
##     configuration parameters and the public signals the door can emit.
##


## Sliding door linear range
export var door_range := 1.0

## Sliding door latch position
export var latch_position := 0.02


func _on_door_grabbed():
	emit_signal("door_grabbed", self)


func _on_door_released():
	emit_signal("door_released", self)


func _on_door_opened():
	emit_signal("door_opened", self)


func _on_door_closed():
	emit_signal("door_closed", self)
