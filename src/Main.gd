extends Spatial

const PUZZLE_MASK_BIT = 0;
const VERTEX_MASK_BIT = 1; # 2
const PUZZLE_MASK = 1
const VERTEX_MASK = 2
const CONNECTION_SCALE = 0.1

var vertex_prefab = preload("res://scenes/Vertex.tscn")
var edge_prefab = preload("res://scenes/Edge.tscn")

onready var camera:Camera = $Camera
onready var input = $InputMonitor
onready var puzzle:Area = $Puzzle

var puzzle_vertices = []  # Stores the physical instances.
var puzzle_edges = []  # Array of arrays
var puzzle_edge_meshes = []  # Contains all the reference objects.
var selected_vertex = null

# Called when the node enters the scene tree for the first time.
func _ready():
	puzzle_vertices = []
	puzzle_edges = []
	
	# Wire up control signals.
	input.connect("tapped", self, "_on_screen_tapped")
	input.connect("dragged", self, "_on_screen_dragged")
	
	# Load first level
	var file = File.new()
	file.open("res://levels/level2.json", File.READ)
	var text = file.get_as_text()
	load_level(text)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_color_changed(id, color_id, color):
	pass

func _on_screen_tapped(pos):
	# Raycast to the puzzle.
	var from = camera.project_ray_origin(pos)
	var to = from + camera.project_ray_normal(pos) * 100
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [], VERTEX_MASK, false, true)
	if result and result['collider']:
		deselect_vertices()
		select_vertex(result['collider'])

func _on_screen_dragged(dxdy):
	# TODO: Raycast to the surface and do a real rotation.
	puzzle.rotate_y(dxdy.x/100)
	puzzle.rotate_x(dxdy.y/100)

func load_level(level_data):
	clear_puzzle()
	
	var parse_result:JSONParseResult = JSON.parse(level_data)
	if parse_result.error != OK:
		print(parse_result.error_string)
		print(parse_result.error_line)
		assert(false)
	var level = parse_result.result
	
	var scale = 0.2
	
	var vertices = level['vertices']
	
	for i in range(len(vertices)):
		var pos = Vector3(vertices[i][0], vertices[i][1], vertices[i][2])
		var new_vert = vertex_prefab.instance()
		new_vert.id = i
		new_vert.translate(pos)
		new_vert.resize(scale)
		puzzle.add_child(new_vert)
		puzzle_vertices.append(new_vert)
	
	# EDGES ARE NOT TRIANGLES!  Instead it's an adjacency matrix!
	# edges[0] = [1, 2, 3]
	# That means vertex 0 connects to 1, 2, and 3.
	var edges = level['edges']
	
	for i in range(len(vertices)):
		puzzle_edges.append([])
		var src_id = i
		var src_pos:Vector3 = Vector3(vertices[i][0], vertices[i][1], vertices[i][2])
		for dst_id in edges[src_id]:
			var dst_pos:Vector3 = Vector3(vertices[dst_id][0], vertices[dst_id][1], vertices[dst_id][2])
			var connection = edge_prefab.instance()
			connection.connect_edge(src_pos, dst_pos)
			puzzle_edges[src_id].append(dst_id)
			puzzle_edge_meshes.append(connection)
			puzzle.add_child(connection)

func clear_puzzle():
	for v in puzzle_vertices:
		puzzle.remove_child(v)
		v.queue_free()
	puzzle_vertices = []
	for e in puzzle_edge_meshes:
		puzzle.remove_child(e)
		e.queue_free()
	puzzle_edges = []
	puzzle_edge_meshes = []
	
func deselect_vertices():
	if selected_vertex != null:
		selected_vertex.disconnect("color_changed", self, "_on_color_changed")

func select_vertex(vert):
	selected_vertex = vert
	selected_vertex.connect("color_changed", self, "_on_color_changed")
	selected_vertex.on_select()
