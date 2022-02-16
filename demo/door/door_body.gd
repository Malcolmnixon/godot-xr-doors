class_name DoorBody
extends RigidBody


##
## Basic Door Body script
##
## @desc:
##     This script is the base class for door body management.
##
##     The door can be in one of three states - LATCHED, OPEN, or GRABBED.
##
##     When the door is LATCHED, its physics is set to RigidBody.MODE_STATIC to
##     prevent any motion. The player may open the door by grabbing the handle
##     (and optionally twisting). This will put the door into the GRABBED state.
##
##     When the door is OPEN, its physics is set to RigidBody.MODE_RIGID to 
##     allow environmental physics such as collisions to move the door. If the
##     doors 'latch_on_close' flag is set and the door gets within the latch 
##     distance/angle of closed, then the door will close and transition to 
##     LATCHED.
##
##     When the door is GRABBED, its physics is set to RigidBody.MODE_KINEMATIC
##     to allow direct control of its motion. Motion is applied by having the
##     door move to align to the DoorHandleGrab object the player is holding.
##
##     While the door is GRABBED, a sliding-window averager is used to calculate
##     the doors average velocity. When the door is released, this velocity is 
##     applied to the RigidBody so the player can slam the door.
##


# Enumeration of door states
enum DoorState {
	LATCHED,	# Door is latched closed
	OPEN,		# Door is open and can freely move
	GRABBED,	# Door is grabbed and driven by the player hand
}

# Door body origin position in relationship to the parent door
var _door_origin := Vector3.ZERO

# Door state (LATCHED, OPEN, GRABBED) - initially invalid
var _door_state = -1

# Is the handle grabbed
var _handle_grabbed := false

# Can the door be opened
var _can_open_door := true

# Door API
onready var _door_api : DoorApi = get_parent()

# Door handle origin location
onready var _handle_origin : Spatial = $DoorHandleOrigin

# Door handle grab
onready var _handle_grab : DoorHandleGrab = $DoorHandleOrigin/DoorHandleGrab


func _ready():
	# Save our origin relative to the parent hinged door
	_door_origin = transform.origin
	
	# Get the grab handle and connect the events
	_handle_grab.connect("picked_up", self, "_on_handle_grab_picked_up")
	_handle_grab.connect("handle_dropped", self, "_on_handle_grab_dropped")


# Set the door state
func _set_door_state(var new_state) -> int:
	# Skip if no change
	if new_state == _door_state:
		return _door_state

	# Update the door state
	var previous_state = _door_state
	_door_state = new_state

	# Handle physics transitions
	if new_state == DoorState.LATCHED:
		# Set physics to MODE_STATIC if latching
		mode = RigidBody.MODE_STATIC
		
		# Report closed when going from OPEN/GRABBED -> LATCHED
		if previous_state == DoorState.OPEN or previous_state == DoorState.GRABBED:
			_door_api._on_door_closed()
	elif new_state == DoorState.GRABBED:
		# Set physics to MODE_KINEMATIC so the user can move the door
		mode = RigidBody.MODE_KINEMATIC
		_clear_motion_averager();
		
		# Report opened when going from LATCHED -> GRABBED
		if previous_state == DoorState.LATCHED:
			_door_api._on_door_opened()
	else:
		# Door is open, set physics to MODE_RIGID for environmental effects
		mode = RigidBody.MODE_RIGID
		_apply_average_motion()

	# Return the previous state
	return previous_state


# Called when the user grabs the door handle
func _on_handle_grab_picked_up(var _pickable):
	# Indicate the handle is grabbed and try to grab the door
	_handle_grabbed = true
	
	# Attempt to grab the door
	if _door_state == DoorState.OPEN:
		# Door is already open, we can grab it
		_set_door_state(DoorState.GRABBED)
	elif _door_state == DoorState.LATCHED and !_door_api.door_locked and _can_open_door:
		# Door is latched, but we can open it
		_set_door_state(DoorState.GRABBED)

	# Report the door grabbed (emits public signal)
	_door_api._on_door_grabbed()

# Called when the user releases the door handle
func _on_handle_grab_dropped(var _pickable):
	# Indicate the handle is not grabbed
	_handle_grabbed = false

	# If the door is grabbed then release it
	if _door_state == DoorState.GRABBED:
		_set_door_state(DoorState.OPEN)

	# Report the door released (emits public signal)
	_door_api._on_door_released()


# Clear the motion averager
func _clear_motion_averager():
	push_error("Door handle motion averaging logic must be overridden")


# Apply the average motion
func _apply_average_motion():
	push_error("Door handle motion averaging logic must be overridden")
