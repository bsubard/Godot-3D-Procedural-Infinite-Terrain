extends CharacterBody3D

# --- Original Variables (Unchanged) ---
const SPEED = 10.0
const JUMP_VELOCITY = 5
@onready var pivot: Node3D = $Node3D
@export var sensitivity = 0.25
var is_mouse_input_enabled = true

# --- FOG CONTROL VARIABLES (Modified Exports) ---
@export_group("Fog Control") # Added for Inspector clarity
# 1. **SETUP REQUIRED:** Drag your 'Sky3D' (WorldEnvironment) node here.
@export var sky_node_path: NodePath

# 2. **VERIFY PATH:** Reference to the Camera3D node *inside* this Player scene.
#    Make sure "Node3D/SpringArm3D/Camera3D" matches your structure!
@onready var camera: Camera3D = $Node3D/SpringArm3D/Camera3D

# This will hold the actual Sky3D (WorldEnvironment) node from the main scene
var sky_node: WorldEnvironment

# Fog settings - These values from the Inspector will now be used directly
@export var FOG_TRIGGER_Y: float = -20.0
@export var original_fog_density: float = 0.003 # This value will now be respected
@export var normal_fog_color: Color = Color(0.7, 0.7, 0.8) # Renamed for clarity
@export var deep_fog_density: float = 0.15
@export var deep_fog_color: Color = Color(0.1, 0.1, 0.15)

# State variable
var is_in_deep_fog: bool = false
# --- END FOG CONTROL VARIABLES ---



func _ready():
	# --- Original Ready Logic (Unchanged) ---
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- FOG INITIALIZATION (Corrected Initial State Setting) ---
	# Ensure the camera reference is valid FIRST
	if not camera:
		printerr("Player Script Error: Camera node not found at path 'Node3D/SpringArm3D/Camera3D'. Verify the path.")
		set_process(false)
		return

	# Get the Sky3D (WorldEnvironment) Node
	if sky_node_path.is_empty():
		printerr("Player Script Error: 'Sky Node Path' is not set in the Inspector!")
		set_process(false)
		return

	var node = get_node(sky_node_path)
	if not node and get_parent(): # Fallback
		node = get_parent().get_node_or_null(sky_node_path)

	if not node:
		printerr("Player Script Error: Could not find the Sky node using path: ", sky_node_path)
		set_process(false)
		return
	elif not node is WorldEnvironment:
		printerr("Player Script Error: Node at 'Sky Node Path' is not a WorldEnvironment.")
		set_process(false)
		return
	else:
		sky_node = node

	# Validate the Environment resource
	if not sky_node.environment:
		printerr("Player Script Error: Assigned WorldEnvironment ('", sky_node.name, "') has no Environment resource!")
		sky_node = null
		set_process(false)
		return

	# Check if fog is enabled in the Environment
	if not sky_node.environment.fog_enabled:
		printerr("Player Script Warning: Fog is not enabled in the '", sky_node.name, "' Environment resource. Fog changes will have no effect.")

	# --- Explicitly Set Initial Fog State HERE ---
	var start_y = camera.global_position.y
	if start_y < FOG_TRIGGER_Y:
		#print("Setting initial state: Deep Fog")
		sky_node.environment.fog_density = deep_fog_density
		sky_node.environment.fog_light_color = deep_fog_color
		is_in_deep_fog = true # Correctly set initial state flag
	else:
		#print("Setting initial state: Normal Fog (Density: ", original_fog_density, ")")
		sky_node.environment.fog_density = original_fog_density # Use YOUR exported value
		sky_node.environment.fog_light_color = normal_fog_color
		is_in_deep_fog = false # Correctly set initial state flag
	# --- End Initial State Setting ---

	# Optional: Call _check_and_update_fog() once just to be safe, though the above block should handle it.
	# _check_and_update_fog() # This is likely redundant now, but harmless.

	# --- Your Print Statement to Confirm ---
	#if is_instance_valid(sky_node) and sky_node.environment:
		#print("Fog density AFTER initial setup in _ready(): ", sky_node.environment.fog_density)
	# --- END Print Statement ---

	# --- END FOG INITIALIZATION ---
	#print(sky_node.environment.fog_density)

# --- Original Input Logic (Unchanged) ---
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		pivot.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(45))

	if Input.is_key_pressed(KEY_T):
		sky_node.current_time += 1.00
		#print(sky_node.current_time)


# --- Original Physics Logic (Unchanged) ---
func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	var direction = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		direction += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		direction += transform.basis.x

	direction.y = 0
	direction = direction.normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	if Input.is_key_pressed(KEY_SHIFT):
		velocity.x *= 2
		velocity.z *= 2

	velocity.y -= 9.8 * delta * 2
	move_and_slide()


# --- PROCESS FUNCTION FOR FOG CHECK (Unchanged) ---
func _process(delta: float) -> void:
	_check_and_update_fog()
# --- END PROCESS FUNCTION ---


# --- FOG CHECK FUNCTION (Remains efficient - only sets on state change) ---
func _check_and_update_fog():
	# Safety checks
	if not is_instance_valid(sky_node) or not sky_node.environment or not is_instance_valid(camera):
		if is_processing():
			set_process(false)
		return

	var camera_y = camera.global_position.y

	# Logic to Change Fog Density based on Camera Y position
	if camera_y < FOG_TRIGGER_Y:
		# Below Threshold - Change state IF NOT ALREADY deep
		if not is_in_deep_fog:
			# print("Transitioning to Deep Fog") # Debug state change
			sky_node.environment.fog_density = deep_fog_density
			sky_node.environment.fog_light_color = deep_fog_color
			is_in_deep_fog = true
	else:
		# Above or At Threshold - Change state IF coming FROM deep
		if is_in_deep_fog:
			# print("Transitioning to Normal Fog (Density: ", original_fog_density, ")") # Debug state change
			sky_node.environment.fog_density = original_fog_density
			sky_node.environment.fog_light_color = normal_fog_color
			is_in_deep_fog = false
# --- END FOG CHECK FUNCTION ---
