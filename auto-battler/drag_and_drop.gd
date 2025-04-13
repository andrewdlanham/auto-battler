extends Node3D	# Script must be on Node3D to access get_world_3d()

const RAY_LENGTH = 100
const UNIT_MASK = 1
const FLOOR_MASK = 2
const UNIT_FLOOR_MASK = 3	# Enables both layers 1 and 2

var is_dragging
var dragged_object
var dragged_object_collision_shape
var raycast_collision_mask = UNIT_MASK

signal unit_purchase_requested(unit: Unit)

func _ready() -> void:
	%GoldManager.unit_purchase_approved.connect(_on_unit_purchase_approved)

func _process(_delta):
	if is_dragging: update_dragged_object_position()

func _input(event):
	if Input.is_action_just_pressed("LeftClick"):
		print("Left click")
		if is_dragging: return
		raycast_collision_mask = UNIT_MASK
		var raycast_collision_info = get_raycast_collision_info()
		print(raycast_collision_info)
		if !raycast_collision_info.is_empty():
			dragged_object = raycast_collision_info["collider"].get_node("../.")
			print("Dragging: " + dragged_object.name)
			dragged_object_collision_shape = dragged_object.find_child("CollisionShape3D")
			dragged_object_collision_shape.set_disabled(true)
			raycast_collision_mask = FLOOR_MASK
			is_dragging = true
	
	# Handle dropping unit on hex
	elif Input.is_action_just_released("LeftClick"):
		print("Left click released")
		if is_dragging: 
			raycast_collision_mask = UNIT_MASK
			is_dragging = false
			if dragged_object is Unit:
				# Check if Unit is being purchased from shop
				var dropped_hex = get_hex_nearest_to_unit(dragged_object)
				if dropped_hex.hex_type == 'PLAYER' and dragged_object.current_hex.hex_type == 'SHOP':
					unit_purchase_requested.emit(dragged_object)
				elif dropped_hex.hex_type == 'PLAYER':
					snap_to_nearest_hex(dragged_object)
				elif dropped_hex.hex_type == 'SHOP':
					dragged_object.position = dragged_object.current_hex.snap_point.global_transform.origin
				dragged_object.find_child("CollisionShape3D").set_disabled(false)
				dragged_object = null
				dragged_object_collision_shape = null

 
func get_raycast_collision_info():
	
	var space_state = get_world_3d().direct_space_state
	var mouse_position = get_viewport().get_mouse_position()

	var ray_start_point = %MainCamera.project_ray_origin(mouse_position)
	var ray_end_point = ray_start_point + %MainCamera.project_ray_normal(mouse_position) * RAY_LENGTH
	var ray_query = PhysicsRayQueryParameters3D.create(ray_start_point, ray_end_point)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true
	ray_query.collision_mask = raycast_collision_mask
	
	var intersect_ray_result = space_state.intersect_ray(ray_query)
	
	return intersect_ray_result

func update_dragged_object_position():
	var raycast_collision_info = get_raycast_collision_info()
	if raycast_collision_info.is_empty(): return
	if raycast_collision_info["position"]:
		var updated_position = raycast_collision_info["position"]
		dragged_object.global_position = Vector3(
			updated_position.x,
			dragged_object.global_position.y,
			updated_position.z
		)

func snap_to_nearest_hex(unit: Unit):

	# Get closest snap point
	var closest_snap_point = null
	var closest_snap_distance = INF
	for snap_point in get_tree().get_nodes_in_group("Snap Points"):
		var snap_point_origin = snap_point.global_transform.origin
		var distance_to_snap_point = unit.position.distance_to(snap_point_origin)
		if distance_to_snap_point < closest_snap_distance:
			closest_snap_distance = distance_to_snap_point
			closest_snap_point = snap_point
		
	# Snap to closest snap point
	unit.position = closest_snap_point.global_transform.origin
	
	# Set reference to unit on hex
	unit.current_hex.unit_on_hex = null
	closest_snap_point.get_parent().unit_on_hex = unit
	unit.current_hex = closest_snap_point.get_parent()

func _on_unit_purchase_approved(unit: Unit):
	snap_to_nearest_hex(unit)
	%ShopUnits.remove_child(unit)
	%PlayerUnits.add_child(unit)
	

func get_hex_nearest_to_unit(unit: Unit):
	# TODO: Clean up this logic
	# Get closest snap point
	var closest_snap_point = null
	var closest_snap_distance = INF
	for snap_point in get_tree().get_nodes_in_group("Snap Points"):
		var snap_point_origin = snap_point.global_transform.origin
		var distance_to_snap_point = unit.position.distance_to(snap_point_origin)
		if distance_to_snap_point < closest_snap_distance:
			closest_snap_distance = distance_to_snap_point
			closest_snap_point = snap_point
	
	return closest_snap_point.get_parent()
