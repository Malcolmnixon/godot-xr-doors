class_name HingedDoorBody
extends RigidBody


##
## Hinged Door Body script
##
## @desc:
##     This script manages the hinged door body and performs complex physics
##     operations to handle door velocity, limits, and user control.
##
##     The door can be in one of three states - LATCHED, OPEN, or GRABBED.
##
##     When the door is LATCHED, its physics is set to RigidBody.MODE_STATIC to
##     prevent any motion. The player may open the door by grabbing and twisting
##     the handle. This will put the door into the GRABBED state.
##
##     When the door is OPEN, its physics is set to RigidBody.MODE_RIGID to 
##     allow environmental physics such as collisions to move the door. If the
##     doors 'latch_on_close' flag is set and the door gets within 'latch_angle'
##     of closed, then the door will close and transition to LATCHED.
##
##     When the door is GRABBED, its physics is set to RigidBody.MODE_KINEMATIC
##     to allow direct control of its motion. Motion is applied by having the
##     door rotate to align to the DoorHandleGrab object the player is holding.
##
##     While the door is GRABBED, a sliding-window averager is used to calculate
##     the doors angular velocity. When the door is released, this velocity is 
##     applied to the RigidBody so the player can slam the door.
##


# Enumeration of door states
enum DoorState {
	LATCHED,	# Door is latched closed
	OPEN,		# Door is open and can freely swing
	GRABBED		# Door is grabbed and driven by the player hand
}

# Node references
onready var _parent : HingedDoor = get_parent()
onready var _handle_origin : Spatial = $DoorHandleOrigin
onready var _handle_grab : DoorHandleGrab = $DoorHandleOrigin/DoorHandleGrab
onready var _handle_model : Spatial = get_node_or_null("DoorHandleOrigin/DoorHandleModel")

# Door body position in relationship to the parent door
var _door_position := Vector3.ZERO

# Door state (LATCHED, OPEN, GRABBED) - initially invalid
var _door_state = -1

# Is the handle grabbed
var _handle_grabbed := false

# Is the handle twisted to an open position
var _handle_twisted := false

# Angle of the door handle
var _handle_angle := 0.0

# Angle of the door
var _door_angle := 0.0

# Velocity of the door
var _door_velocity := 0.0

# Velocity averaging fields
const averages := 5
var _avg_time_deltas := Array()
var _avg_angle_deltas := Array()
var _avg_last_transform := Transform.IDENTITY
var _average_velocity := 0.0

# Horizontal vector (multiply by this to get only the horizontal components
const horizontal := Vector3(1.0, 0.0, 1.0)

func _ready():
	# Save our position relative to the parent hinged door
	_door_position = transform.origin

	# Get the grab handle and connect the events
	_handle_grab.connect("picked_up", self, "_on_handle_grab_picked_up")
	_handle_grab.connect("handle_dropped", self, "_on_handle_grab_dropped")

	# If no handle model then just assume the handle is twisted
	if !_handle_model:
		_handle_twisted = true
		set_process(false)

	# Set the initial door state
	_door_angle = _measure_door_angle()
	if !_parent.latch_on_close or _handle_twisted or abs(_door_angle) > deg2rad(_parent.latch_angle):
		_set_door_state(DoorState.OPEN)
	else:
		_set_door_state(DoorState.LATCHED)

# Called when the user grabs the door handle
func _on_handle_grab_picked_up(var _pickable):
	# Indicate the door is grabbed
	_handle_grabbed = true

	# If the door is OPEN then transition to GRABBED
	if _door_state == DoorState.OPEN:
		_set_door_state(DoorState.GRABBED)

	# Report the door opened (emits public signal)
	_parent._on_door_grabbed()

# Called when the user releases the door handle
func _on_handle_grab_dropped(var _pickable):
	# Indicate the door is not grabbed
	_handle_grabbed = false

	# Transition to OPEN - the _integrate_forces process may latch it
	_set_door_state(DoorState.OPEN)

	# Report the door released (emits public signal)
	_parent.on_door_released()

# Process door handle mechanics on each frame
func _process(_delta):
	# Skip if no handle model
	if !_handle_model:
		return

	# Measure the door handle angle and whether we consider it twisted to open
	var new_angle := 0.0
	var new_twisted := false
	if _handle_grabbed:
		# Measure the handle twist angle in relationship to the door
		var right : Vector3 = _handle_origin.global_transform.xform_inv(
			_handle_grab.global_transform.xform(
				Vector3.RIGHT))
		new_angle = Vector3.RIGHT.signed_angle_to(right, Vector3.BACK)

		# Clamp the angle to the permitted range
		new_angle = clamp(new_angle, deg2rad(_parent.handle_minimum_angle), deg2rad(_parent.handle_maximum_angle))

		# Detect if the door handle has been twisted to an open position
		if abs(new_angle) > deg2rad(_parent.handle_open_angle):
			new_twisted = true

	# Update the state information and move the door handle model if necessary
	_handle_twisted = new_twisted
	if _handle_angle != new_angle:
		_handle_angle = new_angle
		_handle_model.transform.basis = Basis(Vector3.BACK, new_angle)

	# Detect opening the door
	if _door_state != DoorState.GRABBED and !_parent.door_locked and _handle_twisted and _handle_grabbed:
		# Transition to GRABBED state
		_set_door_state(DoorState.GRABBED)

		# Report door opened - should we only do this if we were LATCHED?
		_parent._on_door_opened()

# Measure the angle of the door body (in relation to the parent door)
func _measure_door_angle() -> float:
	# Get the handle origin position in the parents coordinate space
	var handle_position : Vector3 = _parent.global_transform.xform_inv(_handle_origin.global_transform.origin) * horizontal
	
	# Measure and return the handle angle
	return Vector3.RIGHT.signed_angle_to(handle_position, Vector3.UP)

# Set the door state
func _set_door_state(var door_state):
	# Skip if no change
	if door_state == _door_state:
		return

	# Handle physics transitions
	if door_state == DoorState.LATCHED:
		# Set physics to MODE_STATIC if latching
		mode = RigidBody.MODE_STATIC
	elif door_state == DoorState.GRABBED:
		# User has grabbed the door, clear old averaging data
		_avg_last_transform = global_transform
		_avg_time_deltas.clear()
		_avg_angle_deltas.clear()
		_average_velocity = 0.0

		# Set physics to MODE_KINEMATIC so the user can move the door
		mode = RigidBody.MODE_KINEMATIC
	else:
		# Door is open, set physics to MODE_RIGID for environmental effects
		mode = RigidBody.MODE_RIGID

		# If the transition was from GRABBED -> OPEN then apply average velocity
		# so the door will drift in its previous direction
		if _door_state == DoorState.GRABBED:
			angular_velocity = Vector3(0.0, _average_velocity, 0.0)

	# Update the state
	_door_state = door_state

# Update the sliding-window average angular velocity of the door body
func _update_average_velocity(var time_delta: float, var global_transform: Transform):
	# Calculate the angular delta
	var angular_delta : Vector3 = (global_transform.basis * _avg_last_transform.basis.inverse()).get_euler()

	# Update the last transform
	_avg_last_transform = global_transform

	# Update the average lists
	_avg_time_deltas.push_back(time_delta)
	_avg_angle_deltas.push_back(angular_delta.y)
	if _avg_time_deltas.size() > averages:
		_avg_time_deltas.pop_front()
		_avg_angle_deltas.pop_front()

	# Sum the times
	var total_time := 0.0
	for dt in _avg_time_deltas:
		total_time += dt

	# Sum the angles
	var total_angle := 0.0
	for dd in _avg_angle_deltas:
		total_angle += dd

	# Update the average angular velocity
	_average_velocity = total_angle / total_time

func _latch_door():
	# Set the door state to latched (static)
	_set_door_state(DoorState.LATCHED)
	
	# Set the door to closed
	_door_angle = 0.0
	_door_velocity = 0.0
	transform = Transform(Basis.IDENTITY, _door_position)

	# Report the door closed (emits public signal)
	_parent.call_deferred("_on_door_closed")

# Perform the physics processing on the door body
func _integrate_forces(state):
	# Get the current door angle and velocity
	_door_angle = _measure_door_angle()
	_door_velocity = state.angular_velocity.y
	
	# Check if the player has grabbed the door
	if _door_state == DoorState.GRABBED:
		# Update the kinematic angular velocity
		_update_average_velocity(state.step, state.transform)
		_door_velocity = _average_velocity

		# Get the handle grab position in the parent door space
		var handle_grab_position : Vector3 = _parent.global_transform.xform_inv(_handle_grab.global_transform.origin) * horizontal
		_door_angle = Vector3.RIGHT.signed_angle_to(handle_grab_position, Vector3.UP)

	# Clamp the door angle - also affects velocity when hitting limits
	if _door_angle > deg2rad(_parent.door_maximum_angle):
		_door_angle = deg2rad(_parent.door_maximum_angle)
		if _door_velocity > 0.0:
			_door_velocity = 0.0
	if _door_angle < deg2rad(_parent.door_minimum_angle):
		_door_angle = deg2rad(_parent.door_minimum_angle)
		if _door_velocity < 0.0:
			_door_velocity = 0.0
	
	# Handle auto-latching
	if _door_state == DoorState.OPEN and _parent.latch_on_close:
		if abs(_door_angle) < deg2rad(_parent.latch_angle):
			call_deferred("_latch_door")

	# Apply door close-force and friction terms
	_door_velocity -= _parent.close_force * state.step * _door_angle
	_door_velocity *= 1.0 - _parent.friction * state.step
	
	# Set the door body velocities
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3(0.0, _door_velocity, 0.0)
	
	# Set the door body transform
	state.transform = _parent.global_transform * Transform(Basis(Vector3.UP, _door_angle), _door_position)
