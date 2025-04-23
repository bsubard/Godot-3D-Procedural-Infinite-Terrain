# ChunkManager.gd
extends Node3D

# --- Exports ---
@export var player: CharacterBody3D
@export var chunk_scene: PackedScene
@export var render_distance: int = 4
@export var update_interval: float = 0.5
@export var chunk_size_x: int = 32  # Base size before scaling
@export var chunk_size_z: int = 32  # Base size before scaling
@export var overall_scale: float = 10.0 # <<< ADD THIS and match Chunk.gd's value

# --- Internal State ---
var active_chunks: Dictionary = {}
var current_player_chunk_coords: Vector2i = Vector2i(9999, 9999)
var update_timer: float = 0.0

# Pre-calculate effective size for efficiency
var effective_chunk_size_x: float
var effective_chunk_size_z: float

func _ready():
	# Calculate the actual size of chunks in world space
	effective_chunk_size_x = chunk_size_x * overall_scale
	effective_chunk_size_z = chunk_size_z * overall_scale

	# Basic check to prevent division by zero if scale is invalid
	if effective_chunk_size_x <= 0 or effective_chunk_size_z <= 0:
		printerr("ChunkManager: Invalid overall_scale resulted in zero or negative effective chunk size!")
		effective_chunk_size_x = 1.0 # Assign a default small value to prevent crashes
		effective_chunk_size_z = 1.0
		# Consider disabling the manager or throwing a clearer error
		# set_process(false)

	update_chunks() # Initial chunk load

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer < update_interval:
		return
	update_timer = 0.0

	var new_coords = get_chunk_coords_from_pos(player.global_position)
	if new_coords != current_player_chunk_coords:
		#print("Player moved to chunk: ", new_coords) # Optional debug print
		update_chunks()

# --- MODIFIED FUNCTION ---
func get_chunk_coords_from_pos(pos: Vector3) -> Vector2i:
	# Use the effective (scaled) chunk size for coordinate calculation
	# Ensure we handle the case where effective size might be zero if scale is zero
	if effective_chunk_size_x == 0 or effective_chunk_size_z == 0:
		printerr("Cannot calculate chunk coords: Effective chunk size is zero.")
		return Vector2i(9999,9999) # Return an unlikely coord

	return Vector2i( floori(pos.x / effective_chunk_size_x), floori(pos.z / effective_chunk_size_z) )
# --- END MODIFIED FUNCTION ---

func update_chunks() -> void:
	var new_coords = get_chunk_coords_from_pos(player.global_position)

	# Removed the redundant check `and active_chunks.size() > 0` and `pass`
	# If coords haven't changed, we simply don't proceed further down
	if new_coords == current_player_chunk_coords:
		return # Nothing to update if player is still in the same chunk coord

	current_player_chunk_coords = new_coords

	var required: Dictionary = {}
	# Calculate required chunks based on the NEW player coordinates
	for x in range(current_player_chunk_coords.x - render_distance, current_player_chunk_coords.x + render_distance + 1):
		for z in range(current_player_chunk_coords.y - render_distance, current_player_chunk_coords.y + render_distance + 1):
			required[Vector2i(x, z)] = true

	# Unload chunks no longer required
	# Iterate over a copy because we are modifying the dictionary during iteration
	for coord in active_chunks.keys().duplicate():
		if not required.has(coord):
			#print("Unloading chunk: ", coord) # Optional debug print
			unload_chunk(coord)

	# Load new chunks that are required but not active
	for coord in required.keys():
		if not active_chunks.has(coord):
			#print("Loading chunk: ", coord) # Optional debug print
			load_chunk(coord)

func load_chunk(coord: Vector2i) -> void:
	# Check again just in case of race conditions or logic errors
	if active_chunks.has(coord):
		printerr("Attempted to load chunk that is already active: ", coord)
		return

	var chunk = chunk_scene.instantiate() # No need to cast as Node3D here if you trust the scene
	add_child(chunk)

	# It's good practice to check if the method exists before calling it
	if chunk.has_method("initialize_chunk"):
		# Pass the overall_scale if initialize_chunk needs it,
		# but in the current Chunk.gd setup, it doesn't.
		# It reads its own exported overall_scale.
		chunk.initialize_chunk(coord)
		active_chunks[coord] = chunk
	else:
		printerr("Instantiated chunk scene does not have 'initialize_chunk' method!")
		chunk.queue_free() # Clean up the invalid chunk instance

func unload_chunk(coord: Vector2i) -> void:
	if active_chunks.has(coord):
		var chunk_to_remove = active_chunks[coord]
		active_chunks.erase(coord) # Remove from dictionary first

		# Always check if the instance is still valid before queue_free
		# It might have been freed by other means already
		if is_instance_valid(chunk_to_remove):
			chunk_to_remove.queue_free()
	else:
		printerr("Attempted to unload chunk that is not active: ", coord)
