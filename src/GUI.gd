extends Control

var vscene = preload("res://scenes/GoalIndicator.tscn")

onready var tween:Tween = $Tween
onready var container:GridContainer = $GridContainer

export var button_texture:Resource
export var button_distance:float = 100.0
var distance_scale = 1.0

var active_vertex:Spatial
var palette:Array
var buttons:Array

func _ready():
	get_parent().connect("selection_changed", self, "_on_selection_changed")
	get_parent().connect("puzzle_reset", self, "_on_puzzle_reset")
	get_parent().connect("requirement_added", self, "_on_requirement_added")
	get_parent().connect("requirement_met", self, "_on_requirement_met")
	get_parent().connect("requirement_failed", self, "_on_requirement_failed")

func set_palette(colors):
	# Clear active vertex to avoid old use.
	active_vertex = null
	# Recreate our buttons.
	palette = colors
	# Reset all buttons
	for b in buttons:
		# Don't need to disconnect when freeing.
		b.queue_free()
	buttons = []
	for i in range(len(colors)):
		# The 'live' button will actually report events.
		var b = TextureButton.new()
		var angle = 2.0*PI / float(len(colors))
		b.texture_normal = button_texture
		b.modulate.r = colors[i].r
		b.modulate.g = colors[i].g
		b.modulate.b = colors[i].b
		b.connect("button_down", self, "_on_button_pressed", [i])
		b.rect_rotation = rad2deg(angle * i)
		b.mouse_filter = MOUSE_FILTER_STOP
		b.visible = false
		buttons.append(b)
		self.add_child(b)
		# The fake button will fade when a vert is deselected.
		# We just quickly swap it to where the live buttons used to be.

func _process(delta):
	if active_vertex != null:
		# Project the vertex to local space.
		var pos = get_viewport().get_camera().unproject_position(active_vertex.global_transform.origin)
		for b in buttons:
			b.rect_position = pos + Vector2(button_distance*distance_scale, button_distance*distance_scale)
		
func _on_button_pressed(idx):
	self.active_vertex.set_color(idx, palette[idx])

func _on_puzzle_reset():
	for c in self.container.get_children():
		c.queue_free()

func _on_requirement_added(idx, graph, graph_colors):
	var n = vscene.instance()
	n.graph_offset = Vector2(100, 100)
	n.set_goal(graph, graph_colors, self.palette)
	self.container.add_child(n)

func _on_requirement_met(idx):
	self.container.get_child(idx).on_met()
	
func _on_requirement_failed(idx):
	self.container.get_child(idx).on_failed()
	
func _on_selection_changed(new_selection, old_selection):
	self.active_vertex = new_selection
	if new_selection != null:
		fade_in_buttons(1.0)
		#fade_out_buttons(0.0)
		#tween.interpolate_callback(self, 0.3, "fade_in_buttons", 0.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	else:
		fade_out_buttons(0.0)
		#tween.interpolate_callback(self, 0.3, "fade_out_buttons", 1.0, 0.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
		
func fade_out_buttons(amount):	
	for b in buttons:
		b.modulate.a = amount
		b.rect_pivot_offset = Vector2(-button_distance*amount, -button_distance*amount)
		b.rect_position = Vector2(button_distance*amount, button_distance*amount)
	
	if amount < 0.01:
		for b in buttons:
			b.visible = false

func fade_in_buttons(amount):
	for b in buttons:
		b.visible = true
	
	for b in buttons:
		b.modulate.a = amount
		b.rect_pivot_offset = Vector2(-button_distance*amount, -button_distance*amount)
		b.rect_position = Vector2(button_distance*amount, button_distance*amount)
