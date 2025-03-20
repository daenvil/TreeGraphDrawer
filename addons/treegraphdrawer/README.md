# TreeGraphDrawer

A control node that arranges its children and sub-children as a tree graph and optionally draws connecting lines between them, with some customization options.

I did this for my own game, I'm not sure how useful this is as an addon, but I think it's a good tool to learn how to lay out trees or even to create other addons from this.

## To-do list for v1.0:

- Bug fixing: there's still some cases where the tree isn't drawn completely correct so there must be some bug in the algorithm that I haven't found yet.
- A way of setting the node's bounding rectangle to nicely fit all of the tree. I think this would be useful to put the tree inside containers and things like that. Right now there's the ``get_bounding_rect()`` method but I don't think it's very good and I haven't tested it.

After that I don't think I'm adding anything else to the addon unless I have a need for it, since I am now procrastinating my own game which I originally created this addon for...

## How to use

Place a TreeGraphDrawer node in your scene tree and add whatever Control nodes you want to it. The TreeGraphDrawer node will take all its visible Control-inheriting children and subchildren and programatically set their positions as if they were nodes in a tree graph with the same hierarchy as they have in the scene.

This is not a Container, so **it will not be automatically updated when its children are edited, added, or removed**. The TreeGraphDrawer node positions its children in its ``_ready()`` function, but you can also manually re-arrange it by calling its ``layout()`` method and with the "Re-arrange Tree" button in the inspector.

### Customization options and public methods

TreeGraphDrawer has a few customization options to choose how it is laid out, whether it draws lines or not, and the format of those lines. There's also a few methods that can be called on a TreeGraphDrawer node.

All of this can be seen in the in-editor documentation or in the node's script.

#### Per-node configuration

You can customize how specific nodes behave by setting the following metadata keys (through the inspector or using ``set_meta()`` on them):

- ``"treegraph_ignore"``: set a node's metadata with this key to true to ignore it while building the tree, effectively treating it as part of its parent node. All its children will be ignored as well.
- ``"treegraph_ignore_children"``: set a node's metadata with this key to true to ignore its children while building the tree, effectively treating it and its children as one single node (same effect as setting the ``"treegraph_ignore"`` key to true on all its children).
- ``"treegraph_origin_point"``: set a node's metadata with this key to a ``Vector2`` to manually set its origin point.
- ``"treegraph_no_incoming_lines"``: set a node's metadata with this key to true to avoid drawing connecting lines towards it from its parent.
- ``"treegraph_no_outgoing_lines"``: set a node's metadata with this key to true to avoid drawing connecting lines from it to its children.
- ``"treegraph_lines_start_point"``: set a node's metadata with this key to a ``Vector2`` to manually set the point from where connecting lines start.
- ``"treegraph_lines_end_point"``: set a node's metadata with this key to a ``Vector2`` to manually set the point where connecting lines end.

If a node is an instance of a scene file, the tree will ignore all of its children by default, treating it as a single tree node. To avoid this, set it as an editable instance (check "Editable Children" in the editor or use [``Node.set_editable_instance()``](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-set-editable-instance) in a script).

## Why not a Container?

A container controls the positioning of its children, but not of its sub-children, so all tree nodes would need to be direct children of the container and you would need to stablish their hierarchy in some other way. It would be possible to do so, but once I realized that I could just re-use the existing tree structure of scenes, I wanted to do it that way instead, since it's much simpler to implement and to use.

I don't have plans of making the equivalent Container class, so feel free to reuse this code to do it yourself if you want.

## Acknowledgements

Most of the logic is based on the algorithms explained in [*Drawing Presentable Trees* by Bill Mill](https://llimllib.github.io/pymag-trees/), specifically on the Wetherell-Shannon algorithm, although with some modifications.
