extends RigidBody3D

@export var fuerza := 25.0
@export var velocidad_max := 6.0

func _physics_process(_delta):
	var entrada := Vector2.ZERO
	var acel := Input.get_accelerometer()
	if acel != Vector3.ZERO:
		entrada = Vector2(acel.x, -acel.y) / 9.8
	else:
		# En el editor no hay acelerómetro: usa las flechas
		entrada = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	apply_central_force(Vector3(entrada.x, 0, entrada.y) * fuerza)
	if linear_velocity.length() > velocidad_max:
		linear_velocity = linear_velocity.normalized() * velocidad_max
