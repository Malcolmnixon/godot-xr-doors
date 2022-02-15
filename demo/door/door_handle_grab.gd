class_name DoorHandleGrab
extends XRToolsPickable

##
## Door Handle Grab script
##
## @desc:
##     This script handles an invisible grabber representing the users hold
##     on the door handle. The door handle grab should be configured with:
##      - Static physics mode (no movement until the player grabs it)
##      - No collision mask as this does not process collisions
##      - Separate layer from the door to prevent door self-collisions
##
##     The door body script monitors the door handle for:
##      - Door handle grabbed - using the 'picked_up' signal
##      - Door handle dropped - using the 'handle_dropped' signal
##      - Rotation for updating the handle model and opening the door
##

## Signal emitted when the handle is dropped
signal handle_dropped(pickable)

## Distance from the handle origin to auto-snap the grab
export var snap_distance := 0.3

# Node references
onready var _origin : Spatial = get_parent()


# Handle auto-snapping the grab
func _process(_delta):
	if picked_up_by:
		# Measure the distance of the handle from the origin
		var origin_pos = _origin.global_transform.origin
		var handle_pos = global_transform.origin
		var distance = handle_pos.distance_to(origin_pos)

		# If too far then drop the handle
		if distance > snap_distance:
			picked_up_by.drop_object()


# Handle letting go of the door handle grab
func let_go(_p_linear_velocity = Vector3(), _p_angular_velocity = Vector3()):
	# Call the base-class to perform the drop, but with no velocity
	.let_go()

	# Snap the handle back to the origin
	transform = Transform.IDENTITY

	# Emit the handle dropped signal
	emit_signal("handle_dropped", self)
