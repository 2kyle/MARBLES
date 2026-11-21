# Game size guide for Blender.
#
# What it does: adds see-through outlines to your Blender scene that show
# exactly how big things are in the game, so your model comes out the right
# size. It doesn't touch anything you've made.
#
# How to use it:
#   1. In Blender, click the "Scripting" tab at the top of the window.
#   2. Click "Open" and pick this file (tools/blender/game_size_guide.py).
#   3. Click the play button (Run Script).
#   4. Go back to the "Layout" tab. You'll see a "GAME SIZE GUIDE" collection.
#
# The outlines can't be clicked by accident. They won't end up in your
# export as long as you tick "Selected Objects" when exporting (see
# docs/BLENDER.md), because they can't be selected. Run the script again any
# time to put fresh outlines back.
#
# Blender is "Z up". The game is "Y up". The glTF exporter turns one into the
# other for you, so just model with Z pointing up.
# The front of a model (the side that faces the marbles) is the side you see
# in Blender's Front view (numpad 1).

import bpy
import bmesh
import math

GUIDE = "GAME SIZE GUIDE"

# The game's built-in pin outline, bottom to top: [height, radius] in metres.
# Copied from scripts/pin.gd (PROFILE). The pin's middle is at 0, so the
# bottom is at -0.5175 and the top at +0.5175.
PIN_PROFILE = [
    [-0.5175, 0.0], [-0.5175, 0.078], [-0.49, 0.096], [-0.42, 0.115], [-0.32, 0.1265],
    [-0.2, 0.122], [-0.1, 0.108], [0.0, 0.088], [0.09, 0.07], [0.16, 0.062],
    [0.22, 0.068], [0.28, 0.085], [0.34, 0.097], [0.39, 0.097], [0.44, 0.088],
    [0.48, 0.07], [0.505, 0.044], [0.5175, 0.0],
]
# The pin's invisible "hit box" in the game (scenes/pin.tscn): a cylinder.
PIN_HIT_RADIUS = 0.1265
PIN_HIT_HEIGHT = 1.035
# A marble, for comparison (scenes/marble.tscn).
MARBLE_RADIUS = 0.3


def guide_collection():
    col = bpy.data.collections.get(GUIDE)
    if col is None:
        col = bpy.data.collections.new(GUIDE)
        bpy.context.scene.collection.children.link(col)
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return col


def add_guide(col, name, mesh):
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    obj.display_type = 'WIRE'
    obj.hide_select = True
    obj.hide_render = True
    return obj


def lathe(name, profile, sides=24):
    """Spin a [height, radius] outline round the Z axis."""
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for k in range(sides):
            a = math.tau * k / sides
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            quad = [rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]]
            if len(set(quad)) == 4:
                try:
                    bm.faces.new(quad)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def main():
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    col = guide_collection()

    add_guide(col, "Pin - game shape", lathe("Pin - game shape", PIN_PROFILE))

    half = PIN_HIT_HEIGHT / 2.0
    add_guide(col, "Pin - hit box (stay inside this)",
              lathe("Pin - hit box", [[-half, 0.0], [-half, PIN_HIT_RADIUS],
                                      [half, PIN_HIT_RADIUS], [half, 0.0]], 32))

    # A marble beside the pin, sitting on the same floor, to show the scale.
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=MARBLE_RADIUS)
    mesh = bpy.data.meshes.new("Marble - for size")
    bm.to_mesh(mesh)
    bm.free()
    marble = add_guide(col, "Marble - for size", mesh)
    marble.location = (0.8, 0.0, -half + MARBLE_RADIUS)

    print("Game size guide added: the '%s' collection." % GUIDE)


main()
