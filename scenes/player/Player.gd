extends CharacterBody2D

signal died

@export var SPEED = 150.0
@export var JUMP_VELOCITY = -350.0
@export var JUMP_TERMINATION_MULTIPLIER = 3
@export var MAX_DASHSPEED = 600
@export var MIN_DASHSPEED = 200
@export var HORIZONTAL_ACCELERATION = 600
@export var PLAYER_DEATH_SCENE: PackedScene
@export_flags_2d_physics var DASH_HAZARD_MASK
@export var footstepParticles: PackedScene

enum State {NORMAL, DASHING}


var playerDeathInstance = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var hasDoubleJump = false
var currentState = State.NORMAL
var isStateNew = true
var defaultHazardMask = 0
var hasDash = false
var shouldSpawnParticle = false

func _ready():
	$HazardArea.connect("area_entered", on_hazard_area_enter)
	$AnimatedSprite2D.connect("frame_changed", on_animated_sprite_frame_changed)
	defaultHazardMask = $HazardArea.collision_mask

func _physics_process(delta):
	match currentState:
		State.NORMAL:
			velocity = process_normal(delta, velocity)
		State.DASHING:
			velocity = process_dashing(delta)
			
	isStateNew = false
	
func change_state(newState: State):
	currentState = newState
	isStateNew = true

func process_dashing(delta):
	if isStateNew:
		$DashParticles.emitting = true
		$HazardArea.collision_mask = DASH_HAZARD_MASK
		$DashArea/CollisionShape2D.disabled = false
		$AnimatedSprite2D.play("jump")
		var moveVector = get_movement_vector()
		var velocityMod = 1
		if moveVector.x != 0:
			velocityMod = sign(moveVector.x)
		else:
			velocityMod = 1 if $AnimatedSprite2D.flip_h else -1
			
		velocity = Vector2(MAX_DASHSPEED * velocityMod, 0)
	
	velocity.x = lerp(0.0, velocity.x, pow(2, -8 * delta))
	
	if abs(velocity.x) < MIN_DASHSPEED:
		call_deferred("change_state", State.NORMAL)
		
	return velocity

func process_normal(delta, velocity: Vector2):
	if isStateNew:
		$DashParticles.emitting = false
		$HazardArea.collision_mask = defaultHazardMask
		$DashArea/CollisionShape2D.disabled = true
	
	var moveVector = get_movement_vector()
	
	velocity.x += moveVector.x * HORIZONTAL_ACCELERATION * delta
	if moveVector.x == 0:
		velocity.x = lerp(velocity.x, 0.0, pow(2, -60 * delta))
	
	velocity.x = clamp(velocity.x, -SPEED, SPEED)
	
	if Input.is_action_just_pressed("jump"):
		shouldSpawnParticle = true
	
	if Input.is_action_just_pressed("jump") and (is_on_floor() or !$CoyoteTimer.is_stopped() or hasDoubleJump):
		velocity.y = JUMP_VELOCITY	
		if !is_on_floor():
			hasDoubleJump = false
	
	if not is_on_floor() and !Input.is_action_pressed("jump"):
		velocity.y += gravity * delta * JUMP_TERMINATION_MULTIPLIER
	else:	
		velocity.y += gravity * delta
		
	if is_on_floor():
		hasDoubleJump = true
		hasDash = true
		
	if (hasDash && Input.is_action_just_pressed("dash")):
		call_deferred("change_state", State.DASHING)
		hasDash = false 
		
	updateAnimation()
	return velocity

func _process(_delta):	
	var was_on_floor = is_on_floor()
	move_and_slide()
	
	if (!was_on_floor and is_on_floor() and shouldSpawnParticle):
		spawn_footsteps(1.5)
		
	if (was_on_floor and !is_on_floor()):
		$CoyoteTimer.start()
	
	
func get_movement_vector():
	var moveVector = Vector2.ZERO
	moveVector.x = Input.get_axis("move_left", "move_right")
	moveVector.y = -1 if Input.is_action_just_pressed("jump") else 0
	return moveVector

func updateAnimation():
	var moveVec = get_movement_vector()
	if (!is_on_floor()):
		$AnimatedSprite2D.play("jump")
	elif moveVec.x != 0:
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")
	
	if moveVec.x != 0:
		$AnimatedSprite2D.flip_h = true if moveVec.x >= 0 else false

func kill():
	if playerDeathInstance == null:
		emit_signal("died")
		playerDeathInstance = PLAYER_DEATH_SCENE.instantiate()
		playerDeathInstance.velocity = velocity
		get_parent().add_child(playerDeathInstance)
		playerDeathInstance.global_position = global_position

func on_hazard_area_enter(area2d):
	call_deferred("kill")
	
func spawn_footsteps(scale = 1):
	var footstep = footstepParticles.instantiate()
	get_parent().add_child(footstep)
	footstep.scale = Vector2.ONE * scale
	footstep.global_position = global_position
	
func on_animated_sprite_frame_changed():
	if ($AnimatedSprite2D.animation == "run" && $AnimatedSprite2D.frame == 0):
		spawn_footsteps()
