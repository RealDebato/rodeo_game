extends TestCase
## Debris definitions and initial rotational states.

const ENVISAT_PATH: String = "res://data/debris/envisat.tres"
const START_SPIN_DEG_S: float = 45.0


static func _envisat() -> DebrisDefinition:
	return load(ENVISAT_PATH) as DebrisDefinition


func test_envisat_definition_is_valid() -> void:
	var definition := _envisat()
	assert_true(definition != null, "could not load " + ENVISAT_PATH)
	if definition == null:
		return
	var errors := definition.validate()
	assert_true(errors.is_empty(), ", ".join(errors))


func test_inertia_tensor_is_symmetric() -> void:
	var definition := DebrisDefinition.new()
	definition.inertia_diagonal_kg_m2 = Vector3(100.0, 200.0, 250.0)
	definition.inertia_off_diagonal_kg_m2 = Vector3(5.0, -3.0, 7.0)
	var tensor := definition.inertia_tensor()
	assert_true(tensor.is_equal_approx(tensor.transposed()), "tensor must be symmetric")
	assert_near(tensor.x.y, 5.0, 1e-6)
	assert_near(tensor.y.x, 5.0, 1e-6)


func test_unphysical_inertia_is_rejected() -> void:
	var definition := DebrisDefinition.new()
	definition.inertia_diagonal_kg_m2 = Vector3(1.0, 1.0, 5.0)  # violates triangle inequality
	assert_true(not definition.validate().is_empty())


func test_initial_speed_is_exactly_the_rule_value() -> void:
	var definition := _envisat()
	var rng := RandomNumberGenerator.new()
	for seed_value: int in range(1, 201):
		rng.seed = seed_value
		var state := InitialStateGenerator.generate(definition, START_SPIN_DEG_S, rng)
		assert_near(rad_to_deg(state.angular_speed()), START_SPIN_DEG_S, 1e-3, "seed %d" % seed_value)


func test_only_the_momentum_direction_is_random() -> void:
	var definition := _envisat()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var a := InitialStateGenerator.generate(definition, START_SPIN_DEG_S, rng)
	var b := InitialStateGenerator.generate(definition, START_SPIN_DEG_S, rng)
	assert_true(a.orientation.is_equal_approx(Quaternion.IDENTITY), "orientation fixed by default")
	assert_true(b.orientation.is_equal_approx(Quaternion.IDENTITY), "orientation fixed by default")
	assert_true(a.angular_momentum.normalized().distance_to(b.angular_momentum.normalized()) > 1e-3,
			"two draws should give different L directions")


func test_same_seed_gives_same_state() -> void:
	var definition := _envisat()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var a := InitialStateGenerator.generate(definition, START_SPIN_DEG_S, rng, true)
	rng.seed = 42
	var b := InitialStateGenerator.generate(definition, START_SPIN_DEG_S, rng, true)
	assert_vec_near(a.angular_momentum, b.angular_momentum, 1e-3)
	assert_near(a.orientation.angle_to(b.orientation), 0.0, 1e-6)


func test_random_directions_are_unit_and_spread() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mean := Vector3.ZERO
	for _i: int in range(2000):
		var v := InitialStateGenerator.random_unit_vector(rng)
		assert_near(v.length(), 1.0, 1e-5)
		mean += v
	assert_true((mean / 2000.0).length() < 0.06, "directions should be isotropic (mean ~ 0)")
