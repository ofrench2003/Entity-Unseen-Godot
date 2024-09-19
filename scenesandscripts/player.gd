extends CharacterBody3D


#-----FIRST PERSON CONTROLLER VARIABLES-----#

#-----Camera3D-----#
@export var mouse_sensitivity: float = 10
@export var FOV: float = 90.0
var mouse_axis := Vector2()
@onready var head := $head
@onready var cam := $head/Camera3D


#-----Moving-----#
var direction := Vector3()
var move_axis := Vector2()
var snap := Vector3()
var sprint_enabled := true
var sprinting := false


#-----Walking-----#
const FLOOR_MAX_ANGLE: float = deg_to_rad(46.0)
@export var gravity: float = 30.0
@export var walk_speed: int = 10
@export var sprint_speed: int = 16
@export var acceleration: int = 8
@export var deacceleration: int = 10
@export var air_control = 0.3 # (float, 0.0, 1.0, 0.05)
@export var jump_height: int = 10
var _speed: int
var _is_sprinting_input := false
var _is_jumping_input := false


#-----GAMEPLAY VARIABLES-----#



# Called when the node enters the scene tree
func _ready() -> void:
	ProjectSettings.set("display/window/size/fullscreen", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	cam.fov = FOV


func _physics_process(delta: float) -> void:

	#----------Movement----------#
	move_axis.x = Input.get_action_strength("up") - Input.get_action_strength("down") # measuring x input
	move_axis.y = Input.get_action_strength("right") - Input.get_action_strength("left") # measuring z input
	if Input.is_action_pressed("sprint"): # activate sprint
		_is_sprinting_input = true
	if Input.is_action_just_pressed("quit"): # quit the game
		get_tree().quit()
	if Input.is_action_just_pressed("fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			print("windowed")
		else:
			print("fullscreen")
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	walk(delta)
	


# Called when there is an input event
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: # move the camera if the mouse moves
		mouse_axis = event.relative
		camera_rotation()

#----------Walking----------#
func walk(delta: float) -> void:
	direction_input()
	if is_on_floor():
		snap = -get_floor_normal() - get_platform_velocity() * delta
		# Workaround for sliding down after jump checked slope
		if velocity.y < 0:
			velocity.y = 0
	else:
		# Workaround for 'vertical bump' when going unchecked platform
		if snap != Vector3.ZERO && velocity.y != 0:
			velocity.y = 0
		snap = Vector3.ZERO
		velocity.y -= gravity * delta
	sprint(delta)
	accelerate(delta)
	set_velocity(velocity)
	# TODOConverter40 looks that snap in Godot 4.0 is float, not vector like in Godot 3 - previous value `snap`
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(true)
	set_max_slides(4)
	set_floor_max_angle(FLOOR_MAX_ANGLE)
	move_and_slide()
	velocity = velocity
	_is_jumping_input = false
	_is_sprinting_input = false

#----------Moving the Camera3D----------#
func camera_rotation() -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if mouse_axis.length() > 0:
		var horizontal: float = -mouse_axis.x * (mouse_sensitivity / 100)
		var vertical: float = -mouse_axis.y * (mouse_sensitivity / 100)
		mouse_axis = Vector2()
		rotate_y(deg_to_rad(horizontal))
		head.rotate_x(deg_to_rad(vertical))
		# Clamp mouse rotation
		var temp_rot: Vector3 = head.rotation
		temp_rot.x = clamp(temp_rot.x, -1.5, 1.5)
		head.rotation = temp_rot

#----------Changing direction based checked camera rotation----------#
func direction_input() -> void:
	direction = Vector3()
	var aim: Basis = get_global_transform().basis
	if move_axis.x >= 0.5:
		direction -= aim.z
	if move_axis.x <= -0.5:
		direction += aim.z
	if move_axis.y <= -0.5:
		direction -= aim.x
	if move_axis.y >= 0.5:
		direction += aim.x
	direction.y = 0
	direction = direction.normalized()

#----------Acceleration when walking----------#
func accelerate(delta: float) -> void:
	# Where would the player go
	var _temp_vel: Vector3 = velocity
	var _temp_accel: float
	var _target: Vector3 = direction * _speed
	_temp_vel.y = 0
	if direction.dot(_temp_vel) > 0:
		_temp_accel = acceleration
	else:
		_temp_accel = deacceleration
	if not is_on_floor():
		_temp_accel *= air_control
	# Interpolation
	_temp_vel = _temp_vel.lerp(_target, _temp_accel * delta)
	velocity.x = _temp_vel.x
	velocity.z = _temp_vel.z
	# Make too low values zero
	if direction.dot(velocity) == 0:
		var _vel_clamp := 0.01
		if abs(velocity.x) < _vel_clamp:
			velocity.x = 0
		if abs(velocity.z) < _vel_clamp:
			velocity.z = 0

func sprint(delta: float) -> void:
	if can_sprint():
		_speed = sprint_speed
		cam.set_fov(lerp(cam.fov, FOV * 1.05, delta * 8))
		sprinting = true
	else:
		_speed = walk_speed
		cam.set_fov(lerp(cam.fov, FOV, delta * 8))
		sprinting = false

func can_sprint() -> bool:
	return (sprint_enabled and is_on_floor() and _is_sprinting_input and move_axis.x >= 0.5)
