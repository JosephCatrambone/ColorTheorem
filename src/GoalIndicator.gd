extends Control

const TEXTURE_SCALE = 0.1
const PUSH_FORCE = 30.0 * TEXTURE_SCALE
const SOLVER_ITERATIONS = 200

export var node_texture:Texture
export var graph_offset:Vector2

var graph:Array
var nodes:Array

func set_goal(subgraph:Array, subgraph_color_indices:Array, subgraph_colors:Array):
	var max_dist_to_center = 0
	
	self.graph = subgraph
	
	for i in range(len(subgraph)):
		var n = TextureRect.new()
		n.texture = node_texture
		n.modulate.r = subgraph_colors[subgraph_color_indices[i]].r
		n.modulate.g = subgraph_colors[subgraph_color_indices[i]].g
		n.modulate.b = subgraph_colors[subgraph_color_indices[i]].b
		n.rect_position.x = i + randf()*10 
		n.rect_position.y = i + randf()*10
		n.rect_scale = Vector2(TEXTURE_SCALE, TEXTURE_SCALE)
		nodes.append(n)
	
	# Spread the nodes out so they're easier to see.  Use a force-directed graph approach.
	for iter in range(SOLVER_ITERATIONS):
		for i in range(len(nodes)):
			var n = nodes[i]
			# Apply a force to every node WRT its neighbors.  
			# Move away from those which it is not neighbors of, move towards those which are.
			var force = Vector2()
			for n2 in nodes:
				var dist = (n.rect_position.distance_squared_to(n2.rect_position))
				force += PUSH_FORCE*(n.rect_position - n2.rect_position) * (1.0 / (1.0 + dist))
			n.rect_position += force
			force = Vector2()
			for nbr_idx in graph[i]:
				var nbr = nodes[nbr_idx]
				var dist = (n.rect_position.distance_squared_to(nbr.rect_position))
				force -= PUSH_FORCE*(n.rect_position - nbr.rect_position) * (1.0 / (1.0 + dist))
			n.rect_position += force
	
	# Calculate the mean.
	var mean_pos = Vector2()
	for n in self.nodes:
		mean_pos += n.rect_position
	mean_pos /= float(len(self.nodes))
	
	# Move to center and calculate bounds.
	for n in self.nodes:
		n.rect_position -= mean_pos
		n.rect_position += graph_offset
		max_dist_to_center = max(max_dist_to_center, n.rect_position.distance_to(Vector2()))
		self.add_child(n)
	
	self.rect_min_size.x = max(100, max_dist_to_center + node_texture.get_width()*TEXTURE_SCALE)
	self.rect_min_size.y = max(100, max_dist_to_center + node_texture.get_height()*TEXTURE_SCALE)
	self.rect_size.x = self.rect_min_size.x
	self.rect_size.y = self.rect_min_size.y
	self.minimum_size_changed()

func on_met():
	self.modulate.a = 0.2

func on_failed():
	self.modulate.a = 1.0

func _draw():
	var texture_offset = Vector2(node_texture.get_width(), node_texture.get_height()) * 0.5 * TEXTURE_SCALE
	for i in range(len(self.graph)):
		var from = Vector2(self.nodes[i].rect_position.x, self.nodes[i].rect_position.y) + texture_offset
		for nbr_idx in self.graph[i]:
			var to = Vector2(self.nodes[nbr_idx].rect_position.x, self.nodes[nbr_idx].rect_position.y) + texture_offset
			.draw_line(from, to, Color.white, 2.0, true)

