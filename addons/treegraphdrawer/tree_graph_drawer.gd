@tool
class_name TreeGraphDrawer extends Control

## A [Control] node which arranges its children and sub-children as a tree graph
## and optionally draws connecting lines between them.

## Set a node's metadata with this key to true to ignore it while building the tree,
## effectively treating it as part of its parent node. All its children will be ignored as well.
const META_KEY_IGNORE := &"treegraph_ignore"
## Set a node's metadata with this key to true to ignore its children while building the tree,
## effectively treating it and its children as one single node
## (same effect as setting the [member META_KEY_IGNORE] key to true on all its children).
const META_KEY_IGNORE_CHILDREN := &"treegraph_ignore_children"
## Set a node's metadata with this key to a [Vector2] to manually set its origin point.
const META_KEY_ORIGIN_POINT := &"treegraph_origin_point"
## Set a node's metadata with this key to true to avoid drawing connecting lines towards it from its parent.
const META_KEY_NO_INCOMING_LINES := &"treegraph_no_incoming_lines"
## Set a node's metadata with this key to true to avoid drawing connecting lines from it to its children.
const META_KEY_NO_OUTGOING_LINES := &"treegraph_no_outgoing_lines"
## Set a node's metadata with this key to a [Vector2] to manually set the point from where connecting lines start.
const META_KEY_LINES_START_POINT := &"treegraph_lines_start_point"
## Set a node's metadata with this key to a [Vector2] to manually set the point where connecting lines end.
const META_KEY_LINES_END_POINT := &"treegraph_lines_end_point"

@export_tool_button("Re-arrange Tree") var _rearrange: Callable = layout

## Minimum separation between sibling nodes.
@export var min_sibling_separation: int = 10 :
	set(value):
		if value != min_sibling_separation:
			min_sibling_separation = value
			layout()

## Minimum separation between parent and children nodes.
@export var min_depth_separation: int = 20 :
	set(value):
		if value != min_depth_separation:
			min_depth_separation = value
			layout()

enum Origin {
	CENTER, ## The origin point is set to the center of the node's bounding rect ([method Control.get_rect]).
	PIVOT_OFFSET, ## The origin point is set to the node's [member pivot_offset] property.
}
## Point to use as the origin of each tree node. This decides the placement of each node in the tree,
## as well as where the connecting lines start/end, if they are enabled.
@export var node_origins := Origin.CENTER :
	set(value):
		if value != node_origins:
			node_origins = value
			layout()

## Whether parent nodes should be centered above their children or not.
## The centering is computed using the origin point of the children, which is affected by the [member node_origins] property.
@export var center_parents := true :
	set(value):
		if value != center_parents:
			center_parents = value
			layout()

enum Direction {
	DOWNWARD, ## Top to bottom, with siblings added rightwards.
	RIGHTWARD, ## Same as [member Direction.LEFTWARD] but mirrored along the y axis.
	LEFTWARD, ## Right to left, with siblings added downwards.
	UPWARD, ## Same as [member Direction.DOWNWARD] but mirrored along the x axis.
}
## Direction towards which the tree draws its children.
@export var direction := Direction.DOWNWARD :
	set(value):
		if value != direction:
			direction = value
			layout()

## If true, the tree layout will be built ignoring node sizes,
## i.e. separation between nodes will be constant and equal to the [member min_*_separation] properties.
@export var ignore_node_sizes := false :
	set(value):
		if value != ignore_node_sizes:
			ignore_node_sizes = value
			layout()

@export_group("Connecting Lines", "lines_")
@export_tool_button("Re-draw Lines") var lines_redraw_lines: Callable = draw_tree_lines
## Whether lines connecting parent nodes with their children should be drawn or not.
## Connecting lines are [Line2D] nodes added as children of the parent node they are attached to,
## they can be cleaned up by setting this property to false.
@export var lines_enabled := true :
	set(value):
		if value != lines_enabled:
			lines_enabled = value
			draw_tree_lines()

## Sets the [member Line2D.antialiased] property on each connecting line.
@export var lines_antialiased := true :
	set(value):
		if value != lines_antialiased:
			lines_antialiased = value
			draw_tree_lines()

## Sets the [member Line2D.width] property on each connecting line.
@export var lines_width := 2 :
	set(value):
		if value != lines_width:
			lines_width = value
			draw_tree_lines()

## Sets the [member Line2D.default_color] property on each connecting line.
@export var lines_color := Color.WHITE :
	set(value):
		if value != lines_color:
			lines_color = value
			draw_tree_lines()

enum LineShape {
	LINEAR, ## Straight lines.
	SQUARE, ## Lines are composed of vertical and horizontal straight segments.
	BEZIER_CUBIC, ## Cubic Bézier curves.
}
## Shape of the connecting lines.
@export var lines_shape := LineShape.LINEAR :
	set(value):
		if value != lines_shape:
			lines_shape = value
			draw_tree_lines()

const _OFFSET_KEY := &"_treegraph_ws_offset"
const _POS_KEY := &"_treegraph_tree_position"
const _LINE_KEY := &"_treegraph_line"
var _lines: Array[Line2D] = []

func _ready() -> void:
	layout()

## [color=orange][b]Experimental: may be changed or removed in the future.[/b][/color] Returns a [Rect2] representing the minimum-sized rectangle that encompasses the given node and all of its children.
func get_bounding_rect(node: Control) -> Rect2:
	var children := _get_visible_control_children(node)
	if not children:
		return node.get_rect()
	var rect := node.get_rect()
	for c: Control in children:
		var child_rect := get_bounding_rect(c)
		rect = rect.expand(position + child_rect.position)
		rect = rect.expand(position + child_rect.position + child_rect.size)
		rect = rect.expand(position + child_rect.position + Vector2(child_rect.size.x, 0))
		rect = rect.expand(position + child_rect.position + Vector2(0, child_rect.size.y))
	return rect

## Arranges the whole tree according to its current properties, removing and re-drawing connecting lines if needed.
## [b]Will override any manual positioning[/b].
func layout() -> void:
	var v_space := _ws_minimum_layout(self)
	_apply_offsets(self)
	_set_global_positions(self, v_space)
	draw_tree_lines()

## Removes any existing connecting lines and re-draws them if [member lines_enabled] is on.
func draw_tree_lines() -> void:
	for line: Line2D in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	if lines_enabled:
		for c: Control in _get_visible_control_children(self):
			_draw_lines_from_node(c)

## Returns a unit vector in the direction in which siblings are added (e.g. rightward in a downward tree).
func u_vector() -> Vector2:
	if direction == Direction.LEFTWARD or direction == Direction.RIGHTWARD:
		return Vector2.DOWN
	return Vector2.RIGHT

## Returns a unit vector in the parent-to-child direction (e.g. downward in a downward tree).
func v_vector() -> Vector2:
	match direction:
		Direction.UPWARD:
			return Vector2.UP
		Direction.LEFTWARD:
			return Vector2.LEFT
		Direction.RIGHTWARD:
			return Vector2.RIGHT
	return Vector2.DOWN


func _get_visible_control_children(node: Control, clear_lines := false) -> Array[Control]:
	var children: Array[Control]
	if (node.get_meta(META_KEY_IGNORE_CHILDREN, false) or node.get_meta(META_KEY_IGNORE, false)):
		return children
	for c: Node in node.get_children():
		if node != self and node.scene_file_path and not is_editable_instance(node) and c.owner == node:
			continue ## Ignore children of packed scenes, unless they are set as editable
		if c is Control and c.visible and not c.get_meta(META_KEY_IGNORE, false):
			children.append(c)
		if clear_lines and c is Line2D and c.has_meta(_LINE_KEY) and c.get_meta(_LINE_KEY):
			c.queue_free()
	return children

func _get_node_end_point(node: Control) -> Vector2:
	if node.has_meta(META_KEY_LINES_END_POINT):
		var meta: Variant = node.get_meta(META_KEY_LINES_END_POINT)
		if meta and meta is Vector2:
			return meta as Vector2
	var end: Vector2
	match direction:
		Direction.DOWNWARD:
			end = Vector2(_get_node_origin(node).x, node.get_rect().size.y)
		Direction.UPWARD:
			end = Vector2(_get_node_origin(node).x, 0)
		Direction.RIGHTWARD:
			end = Vector2(node.get_rect().size.x, _get_node_origin(node).y)
		Direction.LEFTWARD:
			end = Vector2(0, _get_node_origin(node).y)
	return end

func _get_node_start_point(node: Control) -> Vector2:
	if node.has_meta(META_KEY_LINES_START_POINT):
		var meta: Variant = node.get_meta(META_KEY_LINES_START_POINT)
		if meta and meta is Vector2:
			return meta as Vector2
	var start: Vector2
	match direction:
		Direction.DOWNWARD:
			start = Vector2(_get_node_origin(node).x, 0)
		Direction.UPWARD:
			start = Vector2(_get_node_origin(node).x, node.get_rect().size.y)
		Direction.RIGHTWARD:
			start = Vector2(0, _get_node_origin(node).y)
		Direction.LEFTWARD:
			start = Vector2(node.get_rect().size.x, _get_node_origin(node).y)
	return start

func _get_actual_position(node: Control, v_space: Dictionary[int, float], depth: int) -> Vector2:
	var tree_pos: Vector2 = node.get_meta(_POS_KEY, Vector2.ZERO)
	if not ignore_node_sizes and depth > 0:
		for i in range(0, depth):
			tree_pos.y += v_space[i]
		tree_pos.y += _get_node_origin(node).dot(v_vector().abs())
	elif depth == 0:
		if direction == Direction.UPWARD or direction == Direction.LEFTWARD:
			tree_pos.y = node.get_rect().size.y
		else:
			tree_pos.y = 0
	match direction:
		Direction.UPWARD:
			tree_pos.y *= -1
		Direction.RIGHTWARD:
			tree_pos = tree_pos.rotated(PI/2)
			tree_pos.x *= -1
		Direction.LEFTWARD:
			tree_pos = tree_pos.rotated(PI/2)
	if depth == 0:
		## In first depth level, do not correct v coordinate
		tree_pos -= _get_node_origin(node).dot(u_vector()) * u_vector()
	else:
		tree_pos -= _get_node_origin(node)
	return tree_pos

func _set_global_positions(node: Control, v_space: Dictionary[int, float], depth := -1) -> void:
	if node != self:
		node.global_position = global_position + _get_actual_position(node, v_space, depth)
	for c: Control in _get_visible_control_children(node):
		_set_global_positions(c, v_space, depth + 1)

func _draw_lines_from_node(node: Control) -> void:
	for c: Control in _get_visible_control_children(node, true):
		if (not c.get_meta(META_KEY_NO_INCOMING_LINES, false)
				and not node.get_meta(META_KEY_NO_OUTGOING_LINES, false)):
			var line := Line2D.new()
			line.width = lines_width
			line.default_color = lines_color
			line.antialiased = lines_antialiased
			line.show_behind_parent = true
			line.set_meta(_LINE_KEY, true)
			node.add_child(line)
			if Engine.is_editor_hint():
				line.owner = get_tree().edited_scene_root
			var start_point: Vector2 = _get_node_end_point(node)
			var end_point: Vector2 = c.position + _get_node_start_point(c)
			line.add_point(start_point)
			var dir_vector := v_vector()
			var depth_distance := absf(end_point.dot(dir_vector) - start_point.dot(dir_vector))
			match lines_shape:
				LineShape.SQUARE:
					line.add_point(start_point + dir_vector * depth_distance / 2)
					line.add_point(end_point - dir_vector * depth_distance / 2)
				LineShape.BEZIER_CUBIC:
					var curve := Curve2D.new()
					curve.add_point(start_point, Vector2(), dir_vector * depth_distance)
					curve.add_point(end_point, -dir_vector * depth_distance)
					var points := curve.tessellate()
					points.remove_at(points.size() - 1)
					points.remove_at(0)
					for point: Vector2 in points:
						line.add_point(point)
			line.add_point(end_point)
			_lines.append(line)
		_draw_lines_from_node(c)

func _get_node_origin(node: Control) -> Vector2:
	if node.has_meta(META_KEY_ORIGIN_POINT):
		var value: Variant = node.get_meta(META_KEY_ORIGIN_POINT)
		if value is Vector2:
			return value as Vector2
	match node_origins:
		Origin.CENTER:
			return node.get_rect().size / 2
		Origin.PIVOT_OFFSET:
			return node.pivot_offset
	return Vector2.ZERO

# Based on the Wetherell-Shannon algorithm according to https://llimllib.github.io/pymag-trees/
# Using u-v coordinates: u = sibling-to-sibling direction (x if tree is vertical), v = parent-child direction (y if tree is vertical).
# 'v_space' = space in the v coordinate required by each depth level to fit its nodes
func _ws_minimum_layout(node: Control,
						depth := -1,
						next_u: Dictionary[int, float] = {},
						u_offsets: Dictionary[int, float] = {},
						v_space: Dictionary[int, float] = {}) -> Dictionary[int, float]:
	var n_children: int = 0
	var children_u_sum: float = 0
	var u_pos: float
	var first_child_in_depth := false
	for c: Control in _get_visible_control_children(node):
		n_children += 1
		v_space = _ws_minimum_layout(c, depth + 1, next_u, u_offsets, v_space)
		children_u_sum += c.get_meta(_POS_KEY, Vector2.ZERO).x
	if not next_u.has(depth):
		next_u[depth] = 0
		first_child_in_depth = true
	if not u_offsets.has(depth):
		u_offsets[depth] = 0
	if node.has_meta(_OFFSET_KEY):
		node.remove_meta(_OFFSET_KEY)
	var origin_u := _get_node_origin(node).dot(u_vector())
	if center_parents and n_children > 0:
		var assigned_u := next_u[depth] + u_offsets[depth]
		if depth >= 0 and not ignore_node_sizes and not first_child_in_depth:
			assigned_u += origin_u
		var desired_u := children_u_sum / n_children
		#print(node.name)
		#print("next_u: ", next_u[depth])
		#print("u_offsets: ", u_offsets[depth])
		#print("assigned_u: ", assigned_u)
		#print("desired_u: ", desired_u)
		if is_equal_approx(desired_u, assigned_u):
			pass
		elif desired_u > assigned_u:
			## Parent wants to be more to the right than originally assigned:
			## -> apply to current depth's offset so it and its siblings are moved to the right
			u_offsets[depth] += desired_u - assigned_u
		else:
			## Parent wants to be more to the left than it is possible:
			## -> save offset so its children are moved to the right by the opposite amount
			node.set_meta(_OFFSET_KEY, assigned_u - desired_u)
	u_pos = next_u[depth] + u_offsets[depth]
	next_u[depth] += min_sibling_separation
	if depth >= 0 and not ignore_node_sizes:
		if not first_child_in_depth:
			u_pos += origin_u
			next_u[depth] += origin_u
		var size_u := absf(node.get_rect().size.dot(u_vector()))
		var size_v := absf(node.get_rect().size.dot(v_vector()))
		next_u[depth] += size_u - origin_u
		if not v_space.has(depth):
			v_space[depth] = 0
		v_space[depth] = maxf(v_space[depth], size_v)
	node.set_meta(_POS_KEY, Vector2(u_pos, depth * min_depth_separation))
	return v_space

func _apply_offsets(node: Control, cum_u_offset: float = 0, depth := -1) -> float:
	if cum_u_offset > 0:
		node.set_meta(_POS_KEY, node.get_meta(_POS_KEY, Vector2.ZERO) + Vector2(cum_u_offset, 0))
	cum_u_offset += node.get_meta(_OFFSET_KEY, 0)
	for c: Node in _get_visible_control_children(node):
		cum_u_offset = _apply_offsets(c, cum_u_offset)
	return cum_u_offset

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not _get_visible_control_children(self):
		warnings.append("TreeGraphDrawer must have visible Control-inheriting children for it to have an effect")
	return warnings
