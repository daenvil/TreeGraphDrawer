@tool
extends EditorPlugin

func _enter_tree():
	add_custom_type(
		"TreeGraphDrawer",
		"Control",
		preload("res://addons/treegraphdrawer/tree_graph_drawer.gd"),
		preload("res://addons/treegraphdrawer/icon.svg"),
	)

func _exit_tree():
	remove_custom_type("TreeGraphDrawer")
