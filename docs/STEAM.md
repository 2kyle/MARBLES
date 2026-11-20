# Putting MARBLES 4P on Steam

The game's Steam code is written and tested. The steps below need **you**: they involve your accounts, your money or Steam's website. Do them in order. The first two take about ten minutes and let you play over Steam with a friend today, using Steam's free test app.

## What's already done

- **Steam online play:** HOST ON STEAM makes a friends-only lobby, and INVITE STEAM FRIENDS opens Steam's invite list. Friends join from the invite or with **Join Game** in the Steam friends list, even when their game is closed. Everyone connects through Steam's relay network, so nobody forwards ports or sees anyone's IP address. Steam names show in the lobby.
- **Play by address** still works, for people without Steam.
- **Rich presence:** friends can see "In a match (frame 3 of 10)", "On the practice island" and so on under **View Game Info** in their Steam friends list.
- **19 achievements**, with an in-game page, a pop-up and icons ready to upload (`steam/achievements/`).
- **Without Steam** (plugin missing or Steam closed), the game runs normally and the Online page says why Steam play is off.

All of it talks to Steam in one file, `scripts/steam_service.gd`. The App ID is in `scripts/steam_config.gd`.

## 1. Install the GodotSteam plugin (5 minutes)

GodotSteam is the free add-on that lets Godot talk to Steam. It isn't in the repository because it's about 30 MB of downloaded program files, so add it like this:

1. Open the project in Godot 4.4.
2. Click the **AssetLib** tab at the top of the editor.
3. Search for **GodotSteam**. Pick **GodotSteam GDExtension 4.4+** (version 4.24 or newer), then **Download**, then **Install**.
4. Restart Godot (**Project → Reload Current Project**).

If the AssetLib version is older, download `godotsteam-4.24-gdextension-plugin-4.4.zip` from https://codeberg.org/godotsteam/godotsteam/releases (the "v4.24-gde" release) and unzip it into the project folder, so you get an `addons/godotsteam/` folder.

To check it worked, run the game with Steam open and go to **ONLINE**. The **HOST ON STEAM** button should be lit up rather than greyed out.

## 2. Try it with a friend (test App ID 480)

Until you have your own App ID, the game uses **480**, Valve's free test app ("Spacewar"). Lobbies, invites and Steam networking all work with it.

1. Both of you need Steam open and signed in, and you need to be Steam friends.
2. Export the game (**Project → Export**, add a Windows preset, **Export Project**). The first time, Godot asks you to download its "export templates": say yes. Godot copies the GodotSteam files next to the .exe automatically.
3. Give your friend the exported folder. Both run it.
4. You: **ONLINE → HOST ON STEAM → INVITE STEAM FRIENDS**, and pick your friend.
5. Your friend accepts the invite in Steam. They land in your lobby. Press **START**.

Good to know with App ID 480:

- Steam shows you as playing "Spacewar". That's normal for the test app.
- The Steam overlay (Shift+Tab, and the invite list) often doesn't work when you run from the Godot editor. Use an exported build to test invites.
- Achievements unlock in the game, but Steam won't show them: Spacewar has its own list. They're saved on your computer and sent to Steam once you switch to your own App ID.

## 3. Get your own App ID

1. Sign up at https://partner.steamgames.com (Steamworks). You'll fill in tax and bank details.
2. Pay the **Steam Direct fee** ($100 per game, earned back once the game makes $1,000).
3. Steam gives you an **App ID** (a number like 2345670).
4. In `scripts/steam_config.gd`, change `APP_ID := 480` to your number.
5. In the same file, set `RESTART_THROUGH_STEAM := true`. If someone starts the game without Steam, it reopens through Steam so the overlay and invites work.

## 4. Add the achievements on Steamworks

On partner.steamgames.com, open your app, then **App Admin → Stats & Achievements → Achievements**. For each row below, click **New Achievement** and fill in:

- **API Name**: the ID exactly as written (the game uses it).
- **Display Name** and **Description**: from the table.
- **Achieved icon**: `steam/achievements/ID.png`.
- **Unachieved icon**: `steam/achievements/ID_locked.png`.

All the icons are 256 × 256 PNGs, which is the size Steam asks for. If Steamworks ever refuses a PNG, open it in any image app and save it as a JPG.

| API Name | Display Name | Description |
| --- | --- | --- |
| FIRST_FRAME | Rolling Start | Finish your first frame. |
| FIRST_MATCH | Full Rack | Play a whole match to the end. |
| FIRST_WIN | Top of the Table | Win a match against at least one other marble. |
| STRIKE | STRIKE! | Knock down every pin on your own in one frame. |
| TURKEY | Turkey | Get three strikes in one match. |
| PINS_500 | Pin Pal | Knock down 500 pins. |
| PHOTO_FINISH | Photo Finish | Be the first marble to reach the pins. |
| BUMPER_CARS | Bumper Cars | Knock another marble off the track. |
| SPLASHDOWN | Splashdown | Fall off the track into the water. |
| ONLINE_MATCH | Long Distance | Finish a match online. |
| FIRST_CRATE | Unboxed | Open a loot crate. |
| LEGENDARY | Legendary Pull | Win a Legendary look from a loot crate. |
| GOLDEN_MARBLE | Golden Marble | Pull the ultra-rare Golden Marble Trophy. |
| DRESSED_UP | Dressed to Roll | Wear a hat and a pair of eyes from the closet. |
| DERBY_WIN | Picked a Winner | Win a bet in the Marble Derby. |
| LONG_SHOT | Long Shot | Win a Derby bet at 5x odds or more. |
| NOTHING_BUT_NET | Nothing but Net | Sink a basket off the trampoline. |
| BACK_OF_THE_NET | Back of the Net | Score a goal on the sports island. |
| PIGGY_BANK | Piggy Bank | Save up 1,000 coins. |
| GEM_HUNTER | Treasure Hunter | Find all 6 secret gems in the jungle. |

When they're all in, click **Publish** (Steamworks changes don't go live until you publish).

To add or change an achievement later: edit `LIST` in `scripts/achievements.gd`, call `Achievements.unlock("ITS_ID")` where it happens, redraw the icons with `godot --script res://tools/make_achievement_icons.gd`, and add it on Steamworks with the same API Name.

## 5. Upload a build

1. Export Windows (and Linux, which Steam Deck can also use) builds from Godot.
2. In Steamworks, under **SteamPipe → Builds**, upload the exported folder. The simplest way is the **SteamPipe GUI tool** from the Steamworks SDK (a free download on partner.steamgames.com), or the web uploader for small builds.
3. Under **Installation → General**, set the launch option to your .exe (for example `MARBLES 4P.exe`).
4. Set the build live on a branch (start with a private beta branch for testing).

## 6. Before you press "Release"

Steam also wants these for the store page. None of them are code:

- Capsule images and screenshots in Steam's sizes (Steamworks lists them under **Store Presence → Graphical Assets**).
- A trailer (strongly recommended).
- A store description, tags and a content survey.
- Steam reviews the build and store page before release (allow a few days).
- Your "Coming Soon" page must be up for at least two weeks before release.

## If something goes wrong

- **HOST ON STEAM is greyed out:** the Online page says why. "Steam isn't set up" means the plugin isn't installed (step 1). "Steam isn't running" means open Steam and sign in.
- **Invites don't appear:** test with exported builds, not the editor (step 2).
- **Friend can't connect:** make sure you're both on the same version of the game.
- **Testing achievements again:** they're kept in `achievements.cfg` in the game's user folder (**Project → Open User Data Folder** in Godot). Delete that file to start over. To reset them on Steam too, run `Achievements.reset()` once from code.
