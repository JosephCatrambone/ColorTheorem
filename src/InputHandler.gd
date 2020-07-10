extends Node

signal dragged(dxdy)
signal tapped(xy)

export var touch_time_threshold:float = 0.4
var touch_event_times:Dictionary = {}
var touch_event_positions:Dictionary = {}

func _unhandled_input(event):
	if event is InputEventScreenTouch:
		var evt_id = event.index
		if event.is_pressed():
			if not evt_id in touch_event_times:
				touch_event_times[evt_id] = OS.get_ticks_msec()
				touch_event_positions[evt_id] = event.position
		else:
			if evt_id in touch_event_times:
				var delta_time = (OS.get_ticks_msec() - touch_event_times[evt_id]) / 1000.0
				if delta_time < touch_time_threshold:
					emit_signal("tapped", event.position)
			else:
				pass # Missed touch down event.  Yikes.
			touch_event_times.erase(evt_id)
			touch_event_positions.erase(evt_id)
	elif event is InputEventScreenDrag:
		var evt_id = event.index
		if evt_id in touch_event_times:
			var delta_position = event.position - touch_event_positions[evt_id]
			touch_event_positions[evt_id] = event.position
			emit_signal("dragged", delta_position)
	elif event is InputEvent:
		pass
