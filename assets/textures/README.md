# Texture slots

The game's look is painted in code (colours, patterns, light and shade, ink outlines). Each slot below is an empty spot waiting for a **hand-made picture**. Drop a file with the slot's name into this folder and it shows up in the game the next time you open Godot. Nothing else to change.

| File name | What it covers | Repeats per metre | Shows at |
|---|---|---|---|
| `lane.png` | the wooden bowling lane floor | 0.5 (one picture covers 2 m) | 70% |
| `pieces.png` | every lane piece: bumpers, ramps, rails, spinners... | 1.5 | 50% |
| `scenery.png` | rocks, cliffs, trees, ruins and buildings, everywhere | 0.35 | 45% |
| `marble.png` | the marbles (bowling balls) | 2 | 35% |
| `hub_grass.png` | the grass on top of the hub island | 0.25 | 100% |

`.jpg` and `.webp` work too. To change how often a picture repeats or how strongly it shows, edit the numbers in `SLOTS` at the top of `scripts/texture_slots.gd`.

## What kind of picture works best

- **Seamless (tileable):** the left edge matches the right and the top matches the bottom, so you can't see where it repeats.
- **Square, 512 or 1024 pixels** is plenty.
- For `lane`, `pieces`, `scenery` and `marble`, **a grey picture works best**: a wood grain, brush strokes, paper, scratches or speckles. Mid grey (50%) changes nothing, lighter bits brighten, darker bits darken, so it adds detail and keeps the game's colours. Coloured pictures work too (they tint things).
- For `hub_grass`, the picture's own colours are used (it's multiplied with the green), so a light grassy picture works well.

## Where to find or make them

- **Make your own:** paint one in Krita or GIMP, or take a photo of real wood, paper or stone and make it seamless (GIMP: Filters > Map > Tile Seamless).
- **Free, made by people:** [Poly Haven](https://polyhaven.com/textures) and [ambientCG](https://ambientcg.com/) (CC0), or [Kenney](https://kenney.nl/) for cartoon ones. Not AI-generated ones.
- **Commission an artist** for a set in the game's style. The table above is a ready-made list of what to ask for.

Add a row to [`assets/CREDITS.md`](../CREDITS.md) for anything you didn't make yourself.
