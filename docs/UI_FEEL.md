# The "pickaxe on rock" UI feel

Every button, panel and card in the game is meant to feel like chipping a
rock with a pickaxe: sharp cut edges, a crunchy **clink!** with a sparkle
of **shine** after it, bits of rock flying off, and a little jolt of the
screen.

It all lives in two scripts:

- `scripts/ui_feel.gd` (**UIFeel**): the look and the touch.
- `scripts/ui_sfx.gd` (**UISfx**): the sounds.

`main.gd` switches it on once at startup with `UIFeel.install(self)`.

## What you'll see and hear

| When | What happens |
|---|---|
| Moving onto a button (mouse, keys or pad) | A tiny pebble **tick**, a glint on its top corner and a quick shine across it |
| Pressing a button | It squashes and springs back, rock chips and sparkles fly from where you hit it, a shine sweeps across, **clink!** then **shine**, and the screen jolts |
| BACK / QUIT / LEAVE / SKIP / RESUME | A softer, lower clink and a smaller jolt |
| Changing a setting (left/right) | A lighter clink |
| Grabbing a draft card | A clink in your player colour, chips, a jolt |
| Closet: wearing a look | Clink and chips. A locked one gives a dull **thunk** and a wobble instead |
| Loot crate | Clink to start, a tick for every prize that rolls past the marker, and a big **CLINK!** when the prize breaks out |

## The look (no textures)

The jagged look is drawn in code, with no image files:

- **Cut corners.** Every box's round corners become straight bevels, each
  corner a different size, so it looks hand-chipped.
- **A stone lip.** A darker edge along the bottom makes each box read as a
  slab you can press.
- **Facets.** A light facet with a jagged edge along the top, a shadow facet
  along the bottom, one big slanted facet across a corner, hairline cracks
  from the corners and a few small nicks knocked out of the rim.
- **A glint** on the lit-up button.

Anything new gets this automatically. If you ever want a box to stay
perfectly round, set its `corner_detail` to anything other than 8 (the
default) and UIFeel leaves it alone.

## Screen shake

**Settings > UI SHAKE** (OFF, LOW, NORMAL, HIGH). It's separate from
CAMERA SHAKE, so players who don't like motion can turn either off. It
only nudges the menu layer and the camera for a fifth of a second, then
puts everything back exactly where it was.

## Swapping in your own sounds

The sounds you hear now are **placeholders made in code**. To use your
own:

1. Make a folder `assets/sounds/ui/` in the project.
2. Drop in files named after the sound you want to replace:

   | File | Plays when |
   |---|---|
   | `clink.wav` | any press |
   | `shine.wav` | just after a press (the sparkle) |
   | `hover.wav` | moving onto a button, and the crate reel ticks |
   | `back.wav` | going back |
   | `deny.wav` | locked / can't afford it |
   | `big.wav` | a loot crate prize breaking out |

   `.ogg` and `.mp3` work too.
3. Want variety? Add several takes: `clink_1.wav`, `clink_2.wav` ... up to
   `_8`. One is picked at random every press (and each play is nudged a
   tiny bit higher or lower so repeats never sound robotic).
4. Open Godot once so it imports them. That's it: your file always wins
   over the placeholder, and no code needs to change.

How loud each one plays is the `LOUDNESS` list at the top of
`scripts/ui_sfx.gd` (in dB: closer to 0 is louder). Everything also
follows the VOLUME setting.

To hear the placeholders on their own (or use them as a starting point in
a sound editor), save them as files:

```
godot --headless --script res://tools/export_ui_sounds.gd -- <folder>
```

## Using it from code

Buttons are hooked up by themselves. For things that aren't real Buttons:

```gdscript
UIFeel.hover(control)                    # tick + glint
UIFeel.strike(control, color, power)     # clink, chips, shine, jolt
UIFeel.deny(control)                     # thunk + wobble
UISfx.play("clink")                      # just a sound
```

Test: `godot --headless --fixed-fps 120 --script res://tests/test_ui_feel.gd`.
Pictures: `tests/shot_ui_feel.gd -- out.png <title|press|settings>`.
