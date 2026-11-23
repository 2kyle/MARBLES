# MARBLES 4P Backlog

This is the to-do list for the game, **most important at the top**. Every night at 2 AM (New York time), Claude takes the top item marked **To do**, builds it on its own branch, and opens a pull request for you to playtest. Once its tests pass it's merged into `main`, and you can ask for tweaks or a revert any time.

**How to use this list**

- **Add an idea:** just tell Claude in the project chat ("add an idea: a loop-de-loop piece"). You can also type it here yourself.
- **Change the order:** move items up or down. The top **To do** item is built next.
- **Remove an idea:** delete it, or tell Claude.
- Items marked *(suggested by Claude)* are Claude's guesses at good next steps. Reorder or delete them freely.

**What the labels mean**

- **To do**: waiting to be built.
- **In review**: built, with a pull request waiting for your playtest. The branch name is next to it.
- **Done**: you approved it and it's in `main`.
- **Dropped**: you said no, so it was left out.

## Up next

1. **To do** · **Colour-blind friendly marbles** *(suggested by Claude)*
   A Settings option that gives each player a pattern or symbol as well as a colour on their marble, name tag and scoreboard row.

2. **To do** · **Loop-de-loop piece** *(suggested by Claude)*
   A new track piece: a full vertical loop. Fast marbles make it round; slow ones fall back.

3. **To do** · **Time trial ghost** *(suggested by Claude)*
   On the hub's practice run, a see-through ghost marble replays your best run so you can race it. Builds on the new TIME TRIAL.

4. **To do** · **More WILD FRAMES rules** *(suggested by Claude)*
   New rule ideas: TINY BALLS (half size), GIANT PINS, REVERSE STEER (left is right), FOG (only see the lane near you), MAGNET MANIA (every marble pulls the others).

5. **To do** · **Biplane rings and online plane** *(suggested by Claude)*
   Floating rings round the island to fly the biplane through (a little race against the clock), and show the plane to online guests too (right now only the person flying it sees the plane; guests see the ball flying).

6. **To do** · **Pick the game's real name** *(suggested by Claude)*
   The title is now **BOWLING WIP** as a stand-in. Pick a name and it changes everywhere at once (`TITLE` in `scripts/main_menu.gd`).

7. **To do** · **Strike replay online** *(suggested by Claude)*
   Show the slow-motion strike replay in online games too, so everyone watches it together (right now it only plays at one computer).

8. **To do** · **Alley decorations, part 2** *(suggested by Claude)*
   A neon "LANES" sign and a shoe-rental counter in the hub. (The pin statues, ball rack and lights round the PLAY sign are done.)

9. **To do** · **SKEE-JUMP extras** *(suggested by Claude)*
   An achievement for a perfect 300, SKEE-JUMP for online guests, and a high-score table per player.

10. **To do** · **SPLASH! and online TIME TRIAL board** *(suggested by Claude)*
   A SPLASH! pop word when a marble falls in water, and show online guests' best runs on the RUN RECORDS board too.

11. **To do** · **Corkscrew TA** *(suggested by Claude)*
   A full spiral that drops under itself. Needs the track to allow crossing over itself (supports and a clearance check by height), so it's a bigger job.

12. **To do** · **Aimed Bounce Pad** *(suggested by Claude)*
   Let the Bounce Pad tilt (rotate key) so it can fling marbles sideways off the track or onto another part of it.

## Needs you (Claude can't do these alone)

- **Steam setup:** install the GodotSteam plugin, try online play with a friend, then get your own Steam App ID. Step-by-step guide: [docs/STEAM.md](docs/STEAM.md).
- **Your first Blender model:** make a bowling pin in Blender and export it to `assets/models/pin/pin.glb`. Beginner guide: [docs/BLENDER.md](docs/BLENDER.md). Once it works, tell Claude what you'd like to model next (marble, hats, track pieces, hub trees and rocks) and it'll hook that up the same way.
- **Sound and music:** you're adding these yourself, so Claude leaves audio out.
- **Textures:** the game has empty texture slots waiting for hand-made pictures (lane wood, pieces, scenery, marbles, hub grass). Drop a file with the right name in `assets/textures/` and it shows up. What to make and where to find free ones: [assets/textures/README.md](assets/textures/README.md).

## In review

*(Nothing yet.)*

## Done

- **Done** · **Polish pass** (November 23)
  WILD FRAME badges (on the tag, the splash, the scoreboard, plus a screen glow and a "next up" teaser), no overlapping text at 720p or 1080p (checked by `tests/find_ui_overlap.gd`), smoother hub (about a quarter of the triangles, draft card pictures only drawn when shown), GRAPHICS also sets edge smoothing and shadows and steps down by itself on slow computers, best time on the time trial clock, tidier pop words, and leaner code.

- **Done** · **Biggest update yet** (November 22)
  Pieces no longer clip into walls or each other (each piece's real outline is checked, and the build cursor shows it). Smoother placing: the cursor speeds up as you hold, moves the way the camera faces, snaps to the nearest free spot, and says why a spot is blocked ("HITS THE WALL"). Tidier screens: draft cards and the key hints always fit, and long menus scroll. Eyes now sit in the ball's finger holes, with the thumb hole as a mouth. Solid hub rocks, stones, garden and cones. More depth: ink outlines, soft shadows in corners, a **GRAPHICS** setting (Low / Medium / High) and texture slots for hand-made art. New: **WILD FRAMES** (every third frame bends a rule, with a Settings switch), a hub **TIME TRIAL** with a RUN RECORDS board, controller **RUMBLE** (with a Settings switch), more pop words (WHOOSH!, ZAP!, GUTTER!, BONK!, WHACK!) and pin statues by the PLAY arch.

- **Done** · **Big Saturday update**
  4 new pieces (Pop Bumper, Pendulum, Magnet, Bounce Pad), 3 new TAs (Oil Slick, Zig-Zag, Rollercoaster Hill), the retro alley look (LOUNGE / ARCADE filter, marquee chase lights, warmer light), forgiving hops with squash and stretch and an air shadow, a retro sign title and livelier menus and draft cards, comic pop words, and the SKEE-JUMP minigame.

- **Done** · **Match awards** *(suggested by Claude)*
  At the end of a match, before the podium, a MATCH AWARDS screen: STRIKE KING (most strikes), PIN CRUSHER (most pins in one roll), SPEED DEMON (fastest marble to the pins) and DEMOLITION (most pieces blown up with bombs). Skippable with any key.

- **Done** · **Strike replay** *(suggested by Claude)*
  After a strike, the roll plays again in slow motion from a low camera by the pins, with cinema bars and a REPLAY tag, then carries on to the STRIKE! banner and the scoreboard. Press any key to skip. Can be switched off in Settings. Not in online games yet.

- **Done** · **Jungle hub island**
  The hub island becomes an explorable jungle: rock mountain walls all round, the casino and sports islands pulled in close and facing the island, temple ruins, a cliff climb, bouncy mushrooms, a hollow log, a crystal cave, a waterfall, six secret gems that pay coins, and parrots, frogs and a monkey.

- **Done** · **Smoother track-altering (TA) placing + 2 new TAs**
  TA previews are a see-through gold piece of track with arrows, a start line with flags, red for danger, a dotted line for where the rest of the track goes, and "WON'T FIT HERE" in red instead of vanishing. New TAs: **S-Bend** and **Narrow Bridge**.

- **Done** · **How to play** pop-up *(suggested by Claude)*
  A short, skippable picture guide (draft, build, roll) with keyboard and controller button prompts. Pops up before the first match, and lives on the title screen as HOW TO PLAY.
