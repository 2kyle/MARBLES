# Rack & Ruin

A party game where friends build a bowling lane together, then race physics marbles down it to smash one shared rack of pins. Built with Godot 4.

![Marbles rolling down the lane](docs/rolling.png)

## Version 0.1: the roll

This first prototype answers one question: **does rolling a marble into the pins feel good?** There's no build phase or online play yet.

- A sloped wooden lane with fixed pieces: two bumper posts, a ramp jump, two angled rails and a funnel.
- Two marbles (two players on one keyboard) that bump into each other.
- Light steering: you can lean your marble, but the lane does most of the work.
- One shared rack of 21 pins (six rows) and the scoring from the design doc.
- A 10-frame match with a scoreboard.

## How to play it

1. **Install Godot.** Download **Godot 4.4 or newer, the standard version** (not ".NET") from <https://godotengine.org/download>. On Windows it's a zip file: unzip it anywhere and double-click the `Godot_v4...exe` inside. There's no installer.
2. **Download this project.** On the GitHub page for this repository, click the green **Code** button, then **Download ZIP**. Unzip it somewhere you'll find it again, like your Documents folder.
   - To test a branch that isn't merged yet, first pick it in the branch menu (top left of the file list, it says `main`), then click **Code → Download ZIP**.
3. **Open it in Godot.** In the Godot Project Manager, click **Import**, browse into the unzipped folder, pick the `project.godot` file, and click **Import & Edit**. The first open takes a few seconds while Godot prepares the files.
4. **Press Play.** Click the ▶ button at the top right of the editor (or press **F5**). The game opens in its own window.

## Controls

| Key | What it does |
| --- | --- |
| **W A S D** | Player 1 (pink marble) leans left, right, forward and back |
| **Arrow keys** | Player 2 (yellow marble) leans |
| **Space** | Start the roll / go to the next frame |
| **R** | Reset the current frame |
| **C** | Turn marble-vs-marble collision on or off |
| **V** | Switch between the follow camera and an overhead view |
| **Esc** | Quit |

## Scoring

| Event | Points |
| --- | --- |
| Each pin your marble knocks down (a chain reaction counts for whoever started it) | 1 |
| Clean sweep: you knock down the last pin standing | +5 |
| First / second / third marble to reach the pins (yellow line) | +3 / +2 / +1 |

If every marble reaches the pins, nobody gets the race bonus. If no marble reaches the pins in 30 seconds, nobody scores that frame.

## Tuning the feel

Most numbers you'll want to tweak are editable in the Godot editor without touching code. Click a node, then change the value in the **Inspector** panel on the right.

| What | Where | Setting |
| --- | --- | --- |
| Steering strength | `scenes/marble.tscn`, root node | Lean Side Force, Lean Forward Force |
| How heavy the marble is | `scenes/marble.tscn`, root node | Mass (heavier scatters pins harder) |
| Bumper kick | `scenes/marble.tscn`, root node | Bumper Kick |
| Pin weight and wobble | `scenes/pin.tscn`, root node | Mass, Center Of Mass |
| Lane steepness | `scenes/course.tscn`, `Slope` node | Rotation X (more negative = steeper) |
| Moving pieces around | `scenes/course.tscn`, `Slope/Pieces` | Drag them in the 3D view |
| Players, frames, time limit, collision | `scenes/main.tscn`, `Main` node | Player Count, Frames Per Match, Roll Time Limit, Marbles Collide |

## How the project is laid out

```
scenes/
  main.tscn          the game: lane, rack, camera, scoreboard
  course.tscn        the lane, pin deck, and fixed pieces
  marble.tscn        a player's marble
  pin.tscn           one bowling pin
  pieces/            bumper post, angled rail, ramp jump, funnel
scripts/
  main.gd            runs frames and the match (the "referee")
  marble.gd          lean steering and bumper kicks
  pin.gd             knocked-down check and who gets credit
  rack.gd            sets up the 21 pins
  scoring.gd         the scoring rules, on their own
  controls.gd        all the key bindings
  camera_rig.gd      follow camera
  hud.gd             scoreboard text
tests/
  test_scoring.gd    checks the scoring rules
  sim_roll.gd        plays frames with no one at the keys and prints results
```

The code is set up for online play later: `main.gd` makes every decision (physics, who arrived first, who gets each pin), and player input only reaches a marble through one function, `_gather_inputs()`. When online play arrives, the host runs `main.gd` and fills in each marble's lean from the network instead of the keyboard.

### Running the tests (optional)

From the project folder in a terminal, with `godot` being the path to your Godot program:

```
godot --headless --script res://tests/test_scoring.gd
godot --headless --fixed-fps 120 --script res://tests/sim_roll.gd
```
