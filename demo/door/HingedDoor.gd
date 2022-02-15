class_name HingedDoor
extends Spatial


##
## Hinged Door API script
##
## @desc:
##     This script exposes the public API for hinged doors. It contains all the
##     configuration parameters and the public signals the door can emit.
##


## Signal emitted when the door handle is grabbed
signal door_grabbed(door)

## Signal emitted when the door handle is released
signal door_released(door)

## Signal emitted when a latched door is opened
signal door_opened(door)

## Signal emitted when a door re-latches
signal door_closed(door)

## Minimum angle the door can swing to (0 is closed)
export(float, -180.0, 180.0, 1.0) var door_minimum_angle := -90.0

## Maximum angle the door can swing to (0 is closed)
export(float, -180.0, 180.0, 1.0) var door_maximum_angle := 0.0

## Minium angle the door handle can swing to (0 is flat)
export(float, -180.0, 180.0, 1.0) var handle_minimum_angle := 0.0

## Maximum angle the door handle can swing to (0 is flat)
export(float, -180.0, 180.0, 1.0) var handle_maximum_angle := 70.0

## Unsigned door handle angle to open the door
export(float, 0.0, 180.0, 1.0) var handle_open_angle := 40.0

## Unsigned door angle to latch the door
export(float, 0.0, 180.0, 1.0) var latch_angle := 3.0

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

func on_door_released():
	emit_signal("door_released", self)

func _on_door_opened():
	emit_signal("door_opened", self)

func _on_door_closed():
	emit_signal("door_closed", self)
