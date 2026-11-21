# MARBLES 4P Backlog

This is the to-do list for the game, **most important at the top**. Every night at 2 AM (New York time), Claude takes the top item marked **To do**, builds it on its own branch, and opens a pull request for you to playtest. Nothing reaches `main` until you approve it.

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

1. **To do** · **Match awards** *(suggested by Claude)*
   At the end of a match, before the podium, show a few fun awards: most strikes, most pins in one roll, fastest marble to the finish, most pieces knocked over.

2. **To do** · **Controller rumble** *(suggested by Claude)*
   Short controller rumbles when a marble hits a bumper, lands a hop, or gets a strike. Add an on/off switch in Settings.

3. **To do** · **Graphics quality setting** *(suggested by Claude)*
   A Low / Medium / High choice in Settings (shadows, clouds, water detail) so the game runs smoothly on older laptops.

4. **To do** · **Colour-blind friendly marbles** *(suggested by Claude)*
   A Settings option that gives each player a pattern or symbol as well as a colour on their marble, name tag and scoreboard row.

5. **To do** · **Loop-de-loop piece** *(suggested by Claude)*
   A new track piece: a full vertical loop. Fast marbles make it round; slow ones fall back.

6. **To do** · **Biplane rings and online plane** *(suggested by Claude)*
   Floating rings round the island to fly the biplane through (a little race against the clock), and show the plane to online guests too (right now only the person flying it sees the plane; guests see the ball flying).

7. **To do** · **Pick the game's real name** *(suggested by Claude)*
   The title is now **BOWLING WIP** as a stand-in. Pick a name and it changes everywhere at once (`TITLE` in `scripts/main_menu.gd`).

8. **To do** · **Strike replay online** *(suggested by Claude)*
   Show the slow-motion strike replay in online games too, so everyone watches it together (right now it only plays at one computer).

9. **To do** · **Alley decorations for the hub** *(suggested by Claude)*
   Giant bowling pin statues by the PLAY arch, a neon "LANES" sign, a shoe-rental counter and a ball rack, all with marquee lights. Left out of the Big Saturday update so it didn't clash with the hub clipping fixes.

10. **To do** · **SKEE-JUMP extras** *(suggested by Claude)*
   An achievement for a perfect 300, SKEE-JUMP for online guests, and a high-score table per player.

11. **To do** · **More pop words** *(suggested by Claude)*
   WHOOSH! on boosters, ZAP! on teleporters, SPLASH! when a marble falls in the water, GUTTER! on a gutter cut.

12. **To do** · **Corkscrew TA** *(suggested by Claude)*
   A full spiral that drops under itself. Needs the track to allow crossing over itself (supports and a clearance check by height), so it's a bigger job.

13. **To do** · **Aimed Bounce Pad** *(suggested by Claude)*
   Let the Bounce Pad tilt (rotate key) so it can fling marbles sideways off the track or onto another part of it.

## Needs you (Claude can't do these alone)

- **Steam setup:** install the GodotSteam plugin, try online play with a friend, then get your own Steam App ID. Step-by-step guide: [docs/STEAM.md](docs/STEAM.md).
- **Your first Blender model:** make a bowling pin in Blender and export it to `assets/models/pin/pin.glb`. Beginner guide: [docs/BLENDER.md](docs/BLENDER.md). Once it works, tell Claude what you'd like to model next (marble, hats, track pieces, hub trees and rocks) and it'll hook that up the same way.
- **Sound and music:** you're adding these yourself, so Claude leaves audio out.

## In review

- **In review** · **Big Saturday update** (branch `claude/project-thread-7x3r7q`)
  4 new pieces (Pop Bumper, Pendulum, Magnet, Bounce Pad), 3 new TAs (Oil Slick, Zig-Zag, Rollercoaster Hill), the retro alley look (LOUNGE / ARCADE filter, marquee chase lights, warmer light), forgiving hops with squash and stretch and an air shadow, a retro sign title and livelier menus and draft cards, comic pop words, and the SKEE-JUMP minigame. Each part is its own commit, so any one can be left out.

## Done

- **Done** · **Strike replay** *(suggested by Claude)*
  After a strike, the roll plays again in slow motion from a low camera by the pins, with cinema bars and a REPLAY tag, then carries on to the STRIKE! banner and the scoreboard. Press any key to skip. Can be switched off in Settings. Not in online games yet.

- **Done** · **Jungle hub island**
  The hub island becomes an explorable jungle: rock mountain walls all round, the casino and sports islands pulled in close and facing the island, temple ruins, a cliff climb, bouncy mushrooms, a hollow log, a crystal cave, a waterfall, six secret gems that pay coins, and parrots, frogs and a monkey.

- **Done** · **Smoother track-altering (TA) placing + 2 new TAs**
  TA previews are a see-through gold piece of track with arrows, a start line with flags, red for danger, a dotted line for where the rest of the track goes, and "WON'T FIT HERE" in red instead of vanishing. New TAs: **S-Bend** and **Narrow Bridge**.

- **Done** · **How to play** pop-up *(suggested by Claude)*
  A short, skippable picture guide (draft, build, roll) with keyboard and controller button prompts. Pops up before the first match, and lives on the title screen as HOW TO PLAY.
