class_name DoorApi
extends Spatial


##
## Door API script
##
## @desc:
##     This script exposes the base public API for doors. All door APIs extend
##     from this script and add additional door-specific properties.
##


## Signal emitted when the door handle is grabbed
signal door_grabbed(door)

## Signal emitted when the door handle is released
signal door_released(door)

## Signal emitted when a latched door is opened
signal door_opened(door)

## Signal emitted when a door re-latches
signal door_closed(door)


## Door self-closing force
export(float, 0.0, 1.0, 0.01) var close_force := 0.0

## Door friction
export(float, 0.0, 10.0, 0.1) var friction := 0.1

## Door bounce-factor at end-stops
export(float, 0.0, 1.0, 0.01) var bounce := 0.25

## Flag to set the door to latch when closed
export var latch_on_close := true

## Flag to lock the door so the handle will not open it
export var door_locked := false


func _on_door_grabbed():
	emit_signal("door_grabbed", self)


func _on_door_released():
	emit_signal("door_released", self)


func _on_door_opened():
	emit_signal("door_opened", self)


func _on_door_closed():
	emit_signal("door_closed", self)
