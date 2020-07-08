extends Spatial

onready var mesh_instance:MeshInstance = $MeshInstance
var mesh:CylinderMesh

func connect_edge(src:Vector3, dst:Vector3):
	call_deferred("_connect_edge", src, dst)

func _connect_edge(src:Vector3, dst:Vector3):
	mesh = mesh_instance.mesh
	var distance = src.distance_to(dst)
	mesh.height = distance/2.0  # Also update the transform, which is 0.5 * scale.
	mesh_instance.translate_object_local(Vector3(0, 0.5 * mesh.height, 0))
	self.transform.origin = src
	if dst.x == src.x and dst.z == src.z:
		self.transform = self.transform.looking_at(dst, Vector3.FORWARD)
	else:
		self.transform = self.transform.looking_at(dst, Vector3.UP)
