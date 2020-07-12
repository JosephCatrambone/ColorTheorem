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
onready var gui = $GUI

# TODO: I don't like how puzzle_requirements is a list of Dicts.  Maybe break it out.
var puzzle_requirement_subgraphs = [] # A list of subgraphs where each subgraph indexes into a list of neighbors. [[nbr idx,] ]
var puzzle_requirement_colors = [] # A list of lists of color palette IDs.
var puzzle_vertex_colors = [] # Map of vertex IDX -> Palette IDX.
var puzzle_palette = []  # Map of Palette IDX -> Color
var puzzle_vertices = []  # Stores the physical instances.
var puzzle_edges = []  # Array of arrays
var puzzle_edge_meshes = []  # Contains all the reference objects.
var selected_vertex = null

signal puzzle_reset
signal selection_changed(new_selection, previous_selection)
signal requirement_added(id, graph, graph_color_idx)
signal requirement_met(id)
signal requirement_failed(id)

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

func _on_color_changed(id, color_id, color):
	# We picked a color, so we can close the select wheel.
	self.puzzle_vertex_colors[id] = color_id
	deselect_vertex()
	update_puzzle_completion()

func _on_screen_tapped(pos):
	# Raycast to the puzzle.
	var from = camera.project_ray_origin(pos)
	var to = from + camera.project_ray_normal(pos) * 100
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to, [], VERTEX_MASK, false, true)
	if result and result['collider'] and result['collider'] != selected_vertex:
		select_vertex(result['collider'])
	else:
		deselect_vertex()

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
	
	var scale = level.get('scale')
	if scale == null:
		scale = 0.5
	
	self.puzzle_palette = []
	for c in level['colors']:
		self.puzzle_palette.append(Color(c[0], c[1], c[2]))
	gui.set_palette(self.puzzle_palette)
	
	var vertices = level['vertices']
	self.puzzle_vertex_colors = []
	
	for i in range(len(vertices)):
		var pos = Vector3(vertices[i][0], vertices[i][1], vertices[i][2])
		var new_vert = vertex_prefab.instance()
		new_vert.id = i
		new_vert.translate(pos)
		new_vert.resize(scale)
		#new_vert.set_color(0, puzzle_palette[0])  # Do this before signaling.
		new_vert.connect("color_changed", self, "_on_color_changed")
		puzzle.add_child(new_vert)
		puzzle_vertices.append(new_vert)
		self.puzzle_vertex_colors.append(0)
	
	# EDGES ARE NOT TRIANGLES!  Instead it's an adjacency matrix!
	# edges[0] = [1, 2, 3]
	# That means vertex 0 connects to 1, 2, and 3.
	var edges = level['edges']
	self.puzzle_edges = []
	
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
	
	# Load all the requirements for this puzzle.
	self.puzzle_requirement_subgraphs = []
	self.puzzle_requirement_colors = []
	var req_id = 0
	# This messy JSON decode is forcing the subgraph to be [[nbr1 of p, nbr 2 of p, ...], [nbr1 of q, nbr 2 of q, ...], ...]
	# It's an array of arrays and we force the elements to be integers.
	for req in level['requirements']:
		var subgraph = []
		for p_idx in range(len(req['subgraph'])):
			var nbrs = []
			for q_idx in req['subgraph'][p_idx]:
				nbrs.append(int(q_idx))
			subgraph.append(nbrs)
		self.puzzle_requirement_subgraphs.append(subgraph)
		var colors = []
		for color_idx in req['colors']:
			colors.append(int(color_idx))
		self.puzzle_requirement_colors.append(colors)
		# This signaling is messy.
		emit_signal("requirement_added", req_id, subgraph, colors)
		req_id += 1

func update_puzzle_completion():
	var all_satisfied = true
	for i in len(self.puzzle_requirement_subgraphs):
		# For each puzzle subgraph...
		if _contains_solution(self.puzzle_edges, self.puzzle_vertex_colors, self.puzzle_requirement_subgraphs[i], self.puzzle_requirement_colors[i]):
			emit_signal("requirement_met", i)
		else:
			emit_signal("requirement_failed", i)
			all_satisfied = false

func clear_puzzle():
	self.puzzle_palette = []
	for v in puzzle_vertices:
		v.disconnect("color_changed", self, "_on_color_changed")
		puzzle.remove_child(v)
		v.queue_free()
	puzzle_vertices = []
	for e in puzzle_edge_meshes:
		puzzle.remove_child(e)
		e.queue_free()
	puzzle_edges = []
	puzzle_edge_meshes = []
	
func deselect_vertex(send_signal=true):
	if selected_vertex != null:
		selected_vertex.on_deselect()
		selected_vertex = null
		if send_signal:
			emit_signal("selection_changed", null, null)

func select_vertex(vert):
	var prev_vertex = selected_vertex
	deselect_vertex(false)
	selected_vertex = vert
	selected_vertex.on_select()
	emit_signal("selection_changed", selected_vertex, prev_vertex)
	
func _contains_solution(graph:Array, graph_colors:Array, subgraph:Array, subgraph_colors:Array, mapping:Dictionary = {}, g_idx_used:Array = [], s_idx_used:Array = []):
	# TODO: This is a horrifying brute force exponential O(x^n) runtime solution.
	# Please for the love of god implement Ullman's paper.

	# When len(s_set) == len(subgraph), we have mapped every element.
	if len(s_idx_used) == len(subgraph):
		return _is_subgraph_isomorphism(mapping, graph, graph_colors, subgraph, subgraph_colors)
	# We have some member of S that is not yet mapped.
	# Try mapping it to each unclaimed element of G.
	for s_idx in range(len(subgraph)):
		if s_idx in s_idx_used:
			continue
		s_idx_used.push_back(s_idx)
		for g_idx in range(len(graph)):
			if g_idx in g_idx_used:
				continue
			g_idx_used.push_back(g_idx)
			mapping[s_idx] = g_idx
			if _contains_solution(graph, graph_colors, subgraph, subgraph_colors, mapping, g_idx_used, s_idx_used):
				return true
			g_idx_used.pop_back()
			mapping.erase(s_idx)
		s_idx_used.pop_back()
	return false

func _is_subgraph_isomorphism(mapping:Dictionary, graph:Array, graph_colors:Array, subgraph:Array, subgraph_colors:Array):
	# Graphs G and H are isomorphic iff there exists a mapping A from V(G) -> V(H) such that A(u)A(v) in E(H) implies uv in E(G).
	# Subgraph is in graph (via the mapping) if,
	# For each vertex V in subgraph S,
	#   Color in S(V) == Color in G(Mapping(V))
	#   For each neighbor W of V in subgraph S, 
	#     mapping(W) is a neighbor of mapping(V) in G AND Color in S(W) == Color in G(Mapping(W))
	for v in range(len(subgraph)):  # subgraph = [ [nbrs of 0, ...], [nbrs of 1, ...], ... ]
		if subgraph_colors[v] != graph_colors[mapping[v]]:
			return false
		for w in subgraph[v]:
			if graph_colors[mapping[w]] != subgraph_colors[w]:
				return false
			if !(mapping[w] in graph[mapping[v]]):
				return false
	return true
	
