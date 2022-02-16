class_name HingedDoorBody
extends DoorBody


##
## Hinged Door Body script
##
## @desc:
##     This script manages the hinged door body and performs complex physics
##     operations to handle door velocity, limits, and user control.
##


# Horizontal vector (multiply by this to get only the horizontal components
const HORIZONTAL := Vector3(1.0, 0.0, 1.0)

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

# Node references
onready var _parent : HingedDoorApi = get_parent()
onready var _handle_model : Spatial = get_node_or_null("DoorHandleOrigin/DoorHandleModel")


func _ready():
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


# Process door handle mechanics on each frame
func _process(_delta):
	# Skip if no handle model
	if !_handle_model:
		return

	# Measure the door handle angle and whether we consider it twisted to open
	var new_angle := 0.0
	var new_can_open := false
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
			new_can_open = true

	# Update the state information and move the door handle model if necessary
	_can_open_door = new_can_open
	if _handle_angle != new_angle:
		_handle_angle = new_angle
		_handle_model.transform.basis = Basis(Vector3.BACK, new_angle)

	# Detect turning the handle to open the door
	if _door_state != DoorState.GRABBED and _handle_grabbed and !_parent.door_locked and _can_open_door:
		_set_door_state(DoorState.GRABBED)


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
		var handle_grab_position : Vector3 = _parent.global_transform.xform_inv(_handle_grab.global_transform.origin) * HORIZONTAL
		_door_angle = Vector3.RIGHT.signed_angle_to(handle_grab_position, Vector3.UP)

	# Clamp the door angle - also affects velocity when hitting limits
	if _door_angle > deg2rad(_parent.door_maximum_angle):
		_door_angle = deg2rad(_parent.door_maximum_angle)
		if _door_velocity > 0.0:
			_door_velocity *= -_parent.bounce
	if _door_angle < deg2rad(_parent.door_minimum_angle):
		_door_angle = deg2rad(_parent.door_minimum_angle)
		if _door_velocity < 0.0:
			_door_velocity *= -_parent.bounce
	
	# Handle auto-latching
	if _door_state == DoorState.OPEN and _parent.latch_on_close:
		if abs(_door_angle) < deg2rad(_parent.latch_angle):
			call_deferred("_latch_door")

	# Apply door close-force and friction terms
	_door_velocity -= _door_angle * _parent.close_force * state.step
	_door_velocity *= 1.0 - _parent.friction * state.step
	
	# Set the door body velocities
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3(0.0, _door_velocity, 0.0)
	
	# Set the door body transform
	state.transform = _parent.global_transform * Transform(Basis(Vector3.UP, _door_angle), _door_origin)


# Called when the user grabs the door handle
func _on_handle_grab_picked_up(var _pickable):
	# Indicate the door is grabbed
	_handle_grabbed = true

	# If the door is OPEN then transition to GRABBED
	if _door_state == DoorState.OPEN:
		_set_door_state(DoorState.GRABBED)

	# Report the door grabbed (emits public signal)
	_parent._on_door_grabbed()


# Measure the angle of the door body (in relation to the parent door)
func _measure_door_angle() -> float:
	# Get the handle origin position in the parents coordinate space
	var handle_position : Vector3 = _parent.global_transform.xform_inv(_handle_origin.global_transform.origin) * HORIZONTAL
	
	# Measure and return the handle angle
	return Vector3.RIGHT.signed_angle_to(handle_position, Vector3.UP)


# Clear the motion averager
func _clear_motion_averager():
	_avg_last_transform = global_transform
	_avg_time_deltas.clear()
	_avg_angle_deltas.clear()
	_average_velocity = 0.0


# Apply the average motion
func _apply_average_motion():
	angular_velocity = Vector3(0.0, _average_velocity, 0.0)


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
	transform = Transform(Basis.IDENTITY, _door_origin)

	# Report the door closed (emits public signal)
	_parent._on_door_closed()
