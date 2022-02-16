class_name SlidingDoorBody
extends DoorBody


##
## Hinged Door Body script
##
## @desc:
##     This script manages the sliding door body and performs complex physics
##     operations to handle door velocity, limits, and user control.
##


# Position of the door
var _door_position := 0.0

# Velocity of the door
var _door_velocity := 0.0

# Velocity averaging fields
const averages := 5
var _avg_time_deltas := Array()
var _avg_distance_deltas := Array()
var _avg_last_transform := Transform.IDENTITY
var _average_velocity := 0.0

# Node references
onready var _parent : SlidingDoorApi = get_parent()


# Called when the node enters the scene tree for the first time.
func _ready():
	# Set the initial door state
	_door_position = _measure_door_position()
	if !_parent.latch_on_close or abs(_door_position) > deg2rad(_parent.latch_position):
		_set_door_state(DoorState.OPEN)
	else:
		_set_door_state(DoorState.LATCHED)


# Perform the physics processing on the door body
func _integrate_forces(state):
	# Get the current door angle and velocity
	_door_position = _measure_door_position()
	_door_velocity = _parent.global_transform.basis.xform_inv(state.linear_velocity).x
	
	# Check if the player has grabbed the door
	if _door_state == DoorState.GRABBED:
		# Update the kinematic linear velocity
		_update_average_velocity(state.step, state.transform)
		_door_velocity = _average_velocity

		# Get the handle grab position in the parent door space
		var handle_grab_position : Vector3 = _handle_origin.transform.xform_inv(_parent.global_transform.xform_inv(_handle_grab.global_transform.origin))
		_door_position = handle_grab_position.x

	# Clamp the door angle - also affects velocity when hitting limits
	if _door_position > _parent.door_range:
		_door_position = _parent.door_range
		if _door_velocity > 0.0:
			_door_velocity *= -_parent.bounce
	if _door_position < 0.0:
		_door_position = 0.0
		if _door_velocity < 0.0:
			_door_velocity *= -_parent.bounce
	
	# Handle auto-latching
	if _door_state == DoorState.OPEN and _parent.latch_on_close:
		if _door_position < deg2rad(_parent.latch_position):
			call_deferred("_latch_door")

	# Apply door close-force and friction terms
	_door_velocity -= _door_position * _parent.close_force * state.step
	_door_velocity *= 1.0 - _parent.friction * state.step
	
	# Set the door body velocities
	state.linear_velocity = _parent.global_transform.basis.xform(Vector3(_door_velocity, 0.0, 0.0))
	state.angular_velocity = Vector3.ZERO
	
	# Set the door body transform
	state.transform = _parent.global_transform * Transform(Basis.IDENTITY, _door_origin + Vector3.RIGHT * _door_position)


# Measure the door position
func _measure_door_position() -> float:
	return (transform.origin - _door_origin).x


# Clear the motion averager
func _clear_motion_averager():
	_avg_last_transform = global_transform
	_avg_time_deltas.clear()
	_avg_distance_deltas.clear()
	_average_velocity = 0.0


# Apply the average motion
func _apply_average_motion():
	linear_velocity = _parent.global_transform.basis.xform(Vector3(_average_velocity, 0.0, 0.0))


# Update the sliding-window average angular velocity of the door body
func _update_average_velocity(var time_delta: float, var global_transform: Transform):
	# Calculate the angular delta
	var linear_delta : Vector3 = _parent.global_transform.basis.xform_inv(global_transform.origin - _avg_last_transform.origin)

	# Update the last transform
	_avg_last_transform = global_transform

	# Update the average lists
	_avg_time_deltas.push_back(time_delta)
	_avg_distance_deltas.push_back(linear_delta.x)
	if _avg_time_deltas.size() > averages:
		_avg_time_deltas.pop_front()
		_avg_distance_deltas.pop_front()

	# Sum the times
	var total_time := 0.0
	for dt in _avg_time_deltas:
		total_time += dt

	# Sum the distances
	var total_distance := 0.0
	for dd in _avg_distance_deltas:
		total_distance += dd

	# Update the average linear velocity
	_average_velocity = total_distance / total_time


func _latch_door():
	# Set the door state to latched (static)
	_set_door_state(DoorState.LATCHED)
	
	# Set the door to closed
	_door_position = 0.0
	_door_velocity = 0.0
	transform = Transform(Basis.IDENTITY, _door_origin)

	# Report the door closed (emits public signal)
	_parent._on_door_closed()
