class_name Particles

## Spawns one-shot particle effects at world positions.
## All effects use GPUParticles2D and self-destruct after emission.
## Static helper — no autoload needed; call Particles.spawn(...) directly.

static func spawn(parent: Node, effect: String, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := GPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	_configure(p, effect)
	# Auto-free once the one-shot burst finishes (no Timer needed).
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.emitting = true

static func _configure(p: GPUParticles2D, effect: String) -> void:
	var mat := ParticleProcessMaterial.new()
	match effect:

		"selection_pulse":
			p.amount = 16
			p.lifetime = 0.4
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 18.0
			mat.emission_ring_inner_radius = 16.0
			mat.emission_ring_height = 2.0
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 30.0
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 40.0
			mat.gravity = Vector3.ZERO
			mat.scale_min = 2.0
			mat.scale_max = 4.0
			mat.color = Color(0.0, 0.90, 0.78, 0.9)

		"death_burst":
			p.amount = 24
			p.lifetime = 0.6
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 8.0
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 120.0
			mat.gravity = Vector3(0, 200, 0)
			mat.scale_min = 2.0
			mat.scale_max = 5.0
			mat.color = Color(0.9, 0.3, 0.1, 0.85)

		"attack_impact":
			p.amount = 10
			p.lifetime = 0.25
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 90.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 140.0
			mat.gravity = Vector3.ZERO
			mat.scale_min = 2.0
			mat.scale_max = 3.0
			mat.color = Color(1.0, 0.75, 0.1, 1.0)

		"building_place":
			p.amount = 20
			p.lifetime = 0.5
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(32, 32, 0)
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 40.0
			mat.initial_velocity_min = 30.0
			mat.initial_velocity_max = 80.0
			mat.gravity = Vector3.ZERO
			mat.scale_min = 2.0
			mat.scale_max = 4.0
			mat.color = Color(0.0, 0.90, 0.78, 0.7)

		"resource_gather":
			p.amount = 8
			p.lifetime = 0.35
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 45.0
			mat.initial_velocity_min = 30.0
			mat.initial_velocity_max = 60.0
			mat.gravity = Vector3(0, 80, 0)
			mat.scale_min = 2.0
			mat.scale_max = 3.0
			mat.color = Color(0.85, 0.65, 0.1, 0.9)

	p.process_material = mat
