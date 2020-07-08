extends Area

signal selected
signal color_changed(id, new_color_index, new_color)

var id:int
var color_index:int
var neighbors:Array

onready var mesh:MeshInstance = $MeshInstance
onready var collision:CollisionShape = $CollisionShape

func add_neighbor(nbr:int):
	pass

func resize(new_size):
	call_deferred("_resize", new_size)

func _resize(new_size):
	mesh.transform = mesh.transform.scaled(Vector3(new_size, new_size, new_size))
	collision.shape.radius = new_size

func change_color(new_color_index:int, new_color: Color):
	self.color_index = new_color_index
	self.new_color = new_color
	var material:Material = mesh.get_surface_material(0)
	material.set("albedo_color", new_color)
	emit_signal("color_changed", self.id, self.color_index, self.new_color)

func on_select():
	print("I was selected!")
