# Making your own models in Blender

This guide takes you from "never opened Blender" to "my own bowling pin is in the game". Everything in the game right now is built from code (simple shapes stuck together). This is how you start replacing those with models you made yourself.

**The short version**

1. Make a model in Blender and save the `.blend` file in `art/blender/`.
2. Export it as a `.glb` file into `assets/models/<name>/<name>.glb`.
3. Run the game. If the game knows that name, it uses your model instead of its built-in one.

Right now the game knows one name: **`pin`**. Save `assets/models/pin/pin.glb` and every bowling pin turns into yours. Delete the file and the old pins come back. You can't break anything by trying.

---

## 1. Install Blender

1. Go to **blender.org** and click **Download**. It's free and open source (made by the Blender Foundation and volunteers).
2. Install it like any other program. Any version from 4.2 onward works with this guide.
3. Open it. Click away the splash screen. You'll see a grey cube, a camera and a light. That's the starting scene.

**Moving around in Blender** (the three things you'll use all the time):

| Do this | How |
|---|---|
| Orbit (spin the view round) | Hold the **middle mouse button** (press the scroll wheel) and drag |
| Pan (slide the view) | **Shift** + middle mouse drag |
| Zoom | Scroll wheel |
| Look from the front | **Numpad 1** (or the View menu > Viewpoint > Front) |
| Frame what's selected | **Numpad .** (full stop) |

Tip: on a laptop with no middle button or numpad, go to **Edit > Preferences > Input** and tick **Emulate 3 Button Mouse** and **Emulate Numpad**. Then Alt + left drag orbits, and the number row works as a numpad.

Tip: Blender's own free beginner videos are great. On YouTube, search for "Blender Fundamentals" on the official Blender channel. Grant Abbitt and Blender Guru (the "donut" series) are also very beginner friendly.

---

## 2. Where files go

```
art/                      Your work files. The game ignores this folder.
  blender/                .blend files (one per model, e.g. pin.blend)
  textures/               Textures you've made or downloaded, at full size,
                          plus their licence files
assets/                   What the game actually loads
  models/
    pin/
      pin.glb             The exported pin (the game looks here)
  textures/               Textures the game uses directly (if any)
  CREDITS.md              Where every outside asset came from (keep it up to date!)
tools/blender/
  game_size_guide.py      A helper that shows the game's sizes inside Blender
```

Why two places? The `.blend` file is your editable "project" file, with everything Blender knows (modifiers, history, extra bits). The `.glb` is the finished, game-ready copy. You always edit the `.blend` and re-export the `.glb`. The `art/` folder has a little hidden file (`.gdignore`) that tells Godot to leave it alone, so Godot doesn't try to load your work files.

**Naming:** lower case, no spaces, use underscores. `pin.blend`, `pin.glb`, `wood_floor.png`. The folder name and the file name must match (`assets/models/pin/pin.glb`).

---

## 3. Sizes and directions (the important bit)

Get these right and your model drops straight in. Get them wrong and it'll be giant, tiny or lying on its side.

- **1 Blender unit = 1 metre = 1 game unit.** Leave Blender's unit scale at 1.
- **Z is up in Blender.** The game uses Y for up, but the exporter swaps them for you. Just model standing up in Blender, the normal way.
- **The front is the side you see in Front view (numpad 1).** That's the side that faces the marbles coming down the lane.
- **Apply your scale before exporting:** select the model, press **Ctrl + A**, choose **All Transforms**. (If you scaled the object in Object Mode, the game might see a different size than you do. This fixes that.)
- **Where the origin is matters.** The origin is the little orange dot. For the pin it must be **in the middle of the pin**, halfway up, not at the bottom (that's how the game's pin physics are set up).

### The pin's sizes

The game's pins are much bigger than real ones (they're marble-sized, for fun):

| | Size |
|---|---|
| Height | 1.035 m (bottom at -0.5175, top at +0.5175, origin in the middle) |
| Widest part (belly) | 0.253 m across (radius 0.1265) |
| A marble, for comparison | 0.6 m across |

The pin's **hit box** (the invisible shape that does the actual bumping) is a plain cylinder of exactly that height and width. Keep your model inside it, or marbles will look like they pass through the edges. Changing the look doesn't change how pins fall, so the game plays the same.

### Use the size guide script

Rather than typing numbers, let Blender show you:

1. Click the **Scripting** tab at the top of Blender.
2. Click **Open**, pick `tools/blender/game_size_guide.py` from this project, then click the **play button** (Run Script).
3. Go back to the **Layout** tab. There's a new **GAME SIZE GUIDE** collection with see-through outlines of the game's pin, its hit box, and a marble.

Model your pin over the outlines. They can't be selected by accident, and they won't be exported as long as you use "Selected Objects" when exporting (below). Hide them with the eye icon in the Outliner (top right) whenever they're in the way.

---

## 4. Your first model: a bowling pin

A pin is the perfect first model, because it's round. You only draw **half of its outline**, and Blender spins it round for you, like a wood lathe.

1. **Start fresh:** File > New > General. Click the cube, press **X**, then **Delete**. Run the size guide script (above).
2. **Add a single point to draw with:** Add > Mesh > Plane. Press **Tab** to go into Edit Mode. Press **M** > **At Center** to merge its four corners into one point.
3. **Look from the front:** numpad 1. Press **G** then **X** to slide the point along, and put it at the bottom centre of the pin outline. Tip: hold **Ctrl** while moving to snap to the grid.
4. **Draw the outline:** with the point selected, press **E** (extrude) and move the mouse up and out to make the next point. Click to place it. Keep pressing **E** and clicking to trace the right-hand edge of the guide outline, from the bottom up to the top of the head. Finish on the centre line at the top. 10 to 15 points is plenty.
5. **Spin it:** press **Tab** to go back to Object Mode. In the panel on the right, click the blue **spanner** (Modifiers) > **Add Modifier** > Generate > **Screw**. Your outline spins into a solid pin. Set **Steps Viewport** and **Render** to about **24** (higher is smoother but heavier) and tick **Merge** (so the top and bottom close up neatly).
6. **Make it smooth:** right click the pin > **Shade Auto Smooth** (or **Shade Smooth**).
7. **Name it:** double click it in the Outliner and call it `Pin`.
8. **Save:** File > Save As > `art/blender/pin.blend` in this project.

Adjust the shape any time: Tab into Edit Mode, pick a point, press **G** to move it. The spun pin updates live.

### Colours (no texture needed yet)

The simplest way to get a white pin with red stripes:

1. Click the red-ball tab on the right (**Material Properties**) and click **New**. Name it `pin_white` and set **Base Color** to white. Lower **Roughness** to about 0.2 for a shiny look.
2. Click **+** next to the material list to add a second slot, click **New**, name it `pin_red`, and make it red.
3. Click the Screw modifier's down-arrow and choose **Apply** (it's now real geometry you can colour). Tab into Edit Mode, press **3** for face select, then **Alt + click** a ring of faces round the neck to select it (**Shift + Alt + click** adds more rings).
4. With `pin_red` highlighted in the list, click **Assign**.

Godot reads these materials (colour, roughness, metal) straight from the export.

### Keep or drop the cartoon face

The game puts its blinking cartoon eyes and smile on top of your pin, at the head. If you'd rather paint or model your own face, open `scripts/pin.gd` and change `FACE_ON_CUSTOM_MODEL := true` to `false`.

---

## 5. Export to the game

1. Click the pin to select it (just your model, not the guide).
2. **Ctrl + A** > **All Transforms**.
3. **File > Export > glTF 2.0 (.glb/.gltf)**.
4. In the panel on the right of the export window:
   - **Format:** glTF Binary (.glb). This packs the model, materials and textures into one file.
   - **Include > Limit to:** tick **Selected Objects**.
   - **Transform:** **+Y Up** should already be ticked. Leave it on.
   - **Mesh:** **Apply Modifiers** should be ticked. Leave it on.
5. Save to this project as `assets/models/pin/pin.glb` (make the `pin` folder if it isn't there).
6. Open (or switch back to) the project in Godot. It notices the new file and imports it by itself. Start a match and look at your pins!

Tip: Blender remembers these export settings, so next time it's just File > Export and Save.

To change the model: edit `pin.blend`, export again over the same `pin.glb`, done. To go back to the built-in pin: delete (or rename) `pin.glb`.

When it's how you like it, commit `art/blender/pin.blend`, `assets/models/pin/pin.glb` and the `pin.glb.import` file Godot makes next to it (or just ask Claude to commit it for you).

### If it looks wrong

| Problem | Fix |
|---|---|
| Huge or tiny | Check the size against the guide, then Ctrl + A > All Transforms, and export again |
| Lying on its side | Model it standing up along Blender's Z, and keep **+Y Up** ticked |
| Floating or sunk into the floor | The origin isn't in the middle. Object > Set Origin > Origin to Geometry usually fixes a pin |
| Faces look see-through or dark in patches | Edit Mode, select all (**A**), then Mesh > Normals > **Recalculate Outside** (Shift + N) |
| The guide outlines show up in the game | Tick **Selected Objects** when exporting, and select only your model |
| The game still shows the old pin | The path must be exactly `assets/models/pin/pin.glb`. Check the Godot Output panel for a warning |

---

## 6. Textures: make your own, or use ones you're allowed to

A **texture** is a picture wrapped onto a model (wood grain, scratches, a painted logo). You can use your own, or ones other people made and clearly said you may use. This project only uses textures **made by people** (photos, scans, hand-painted, or built by an artist in a texture program), not AI-generated ones.

### Making your own

- **Take photos.** A phone photo of wood, carpet, brick or paint, taken straight on in soft even light (a cloudy day is perfect), makes a great texture. It's 100% yours.
- **Paint them.** Free painting programs: **Krita** (krita.org) and **GIMP** (gimp.org). Or paint right onto the model in Blender's **Texture Paint** tab.
- **Make them in Blender.** Blender's procedural texture nodes (Noise, Voronoi, Wave) make patterns you design yourself. Use **Bake** to turn them into an image the game can use.

### Free, human-made textures you can use

These sites give textures away under the **CC0** licence, which means "free for anything, including commercial games, no credit required". Even so, always credit them in `assets/CREDITS.md`. It's kind, and it keeps a record of where everything came from.

| Site | What's there | Notes |
|---|---|---|
| **Poly Haven** (polyhaven.com) | Photo-scanned textures, HDRI skies, 3D models | CC0. Made by their own staff or by artists who give or sell them their work. They've said publicly they don't make assets with generative AI. **Best first choice.** |
| **ambientCG** (ambientcg.com) | Lots of textures (wood, metal, fabric, ground) | CC0, run by one artist. The site doesn't publish an AI policy, so check the asset page for how it was made (photo, scan, or made in a texture program). |
| **Kenney** (kenney.nl) | Game-ready low-poly models, UI, textures | CC0. Made by hand by a small game-art studio. Their cartoony style matches this game well. |

**Before you use any texture, check:**

1. **The licence on that asset's own page**, not just the site's home page. CC0 or "public domain" is the easiest. **CC-BY** is fine too, but you *must* credit the author. Avoid anything marked **NC** (non-commercial) if you ever want to sell the game, and **ND** (no changes).
2. **That it isn't AI-generated.** Some mixed sites (like OpenGameArt or itch.io asset packs) have a bit of everything, and quality and licences vary. If a page doesn't say how it was made, skip it or ask the author.
3. **Write it down** in `assets/CREDITS.md`: what it is, who made it, the link, and the licence. Save a copy of the licence next to it in `art/textures/`.

Avoid sites that let you download but whose licence forbids sharing the file itself (some "free with an account" sites). Your game shares every file with every player.

### Putting a texture on a model

1. Download a texture at **1K or 2K** size (bigger just makes the game slower to load). Put the files in `art/textures/<name>/`.
2. Select your model, press **Tab**, select all (**A**), then **U** > **Smart UV Project**. This "unwraps" the model so a flat picture can wrap round it. (For a round pin, **U** > **Cylinder Projection** while looking from the front also works well.)
3. Click the **Shading** tab at the top. Drag the colour image (often called `..._diff` or `..._color`) from your file browser into the node area, and connect its **Color** dot to the **Base Color** dot of the Principled BSDF.
4. Export the same way as before. The `.glb` carries the picture inside it, so you don't need to copy anything else into the game.

Many downloads come with extra maps (roughness, normal). They make it look nicer. Plug roughness into **Roughness**, and plug the normal map through a **Normal Map** node into **Normal**.

---

## 7. What's next

Once the pin works, more of the game can be opened up the same way: the marble, hats for the closet, track pieces, trees and rocks for the hub. Each one needs a small code change so the game knows its name (like `pin`). Just tell Claude what you've made and it'll hook it up.

**About real people:** CC0 means free, but people made these. If you end up using a site a lot, consider supporting it (Poly Haven and ambientCG both have Patreon). If the game grows and you want art you can't make yourself, hiring an artist is a great way to get a unique look and support someone's work.
