extends Area

signal color_changed(id, new_color_index, new_color)

var id:int
var color_index:int
var color:Color
var neighbors:Array

export var glow_amount:float = 0.3

onready var mesh:MeshInstance = $MeshInstance
onready var collision:CollisionShape = $CollisionShape

func _ready():
	mesh.set_surface_material(0, mesh.get_surface_material(0).duplicate())

func add_neighbor(nbr:int):
	pass

func resize(new_size):
	call_deferred("_resize", new_size)

func _resize(new_size):
	mesh.transform = mesh.transform.scaled(Vector3(new_size, new_size, new_size))
	collision.shape.radius = new_size

func set_color(new_color_index:int, new_color: Color):
	self.color_index = new_color_index
	self.color = new_color
	var material:Material = mesh.get_surface_material(0)
	material.set("albedo_color", color)
	emit_signal("color_changed", self.id, self.color_index, self.color)

func on_select():
	var material:Material = mesh.get_surface_material(0)
	material.set("emission_energy", glow_amount)

func on_deselect():
	var material:Material = mesh.get_surface_material(0)
	material.set("emission_energy", 0.0)
