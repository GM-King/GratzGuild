# GratzGuild

A little celebration. A very serious grats ledger.

GratzGuild is installed in this WoW beta client's AddOns folder and targets interface **16001**. It has no required addons or libraries. The crimson-and-gold interface includes custom painted murloc, orc, troll and tauren artwork.

Version **1.3.2** fixes excessive background work that could cause stuttering, especially in larger guilds. Closed windows no longer rebuild the ledger, report previews or collection; only the visible tab refreshes, and its countdown updates independently. Background roster events are combined over 0.2 seconds and limited to one scan per second. Login, level-ups and manual refreshes still capture immediately. Chat recognition caches phrases and sender lookups, statistics no longer sort the roster, idle celebrations skip playback updates, and unchanged minimap positions no longer reset their anchors.

Saved progress, commands, settings, tracking rules, artwork and sounds remain compatible.

Version **1.3.0** adds a permanent artwork collection, a movable and resizable popup guide, a single male-orc test, and fixes self-debt, self-grats and minimap placement. Five-minute reply windows and the rare Horde sound remain supported.

## Version 1.3.4

The Ledger roster page now has a **Deselect all** button that clears the entire announcement selection, including names hidden by filters. Tracking and balances are preserved.

## Version 1.3.3

Settings now lists all default grats and ding phrases in a scrollable reference. **Gratez** counts as congratulations; **BIG DINGUS** triggers automatic grats. Case, punctuation and stretched repeated letters are accepted. `dingus` alone and `big dinguses` do not count. Your existing customization and saved progress are preserved.

## Installation

Download **GratzGuild-1.3.4.zip** from https://github.com/GM-King/GratzGuild/releases/tag/v1.3.4 and extract the `GratzGuild` folder into your Forever client's `Interface/AddOns` folder. Check that `Interface/AddOns/GratzGuild/GratzGuild.toc` exists, without an extra nested folder. No other addons are required. To update, close WoW and replace the addon folder; retain your WTF folder to preserve saved progress.

The player ZIP includes runtime textures and sounds. Original PNG artwork, development tools and tests are available in the source repository. Website: https://gm-king.github.io/GratzGuild/

## Start using it

1. Restart WoW if it was running when the new addon folder was created. Enable **GratzGuild** in the character-selection AddOns list.
2. Log in and type **`/gg`** or **`/gratzguild`**. The minimap button also opens the ledger; right-click opens Settings and dragging moves it around the minimap.
3. In Settings, edit your messages and press **Save messages & phrases**. Both automations start enabled: **Ding!** for your level-ups and **Gratz!** for guildmates' dings.
4. Use the Ledger's announcement checkboxes, then open Announcements, review the exact preview and press **Send to Guild**. Reports have a heading and one guildmate per line. Selecting more than 10 names requires confirmation before the report is queued.

`/gg collection` opens the Collection. `/gg settings` opens Settings. `/gg announce` opens the report preview. `/gg resetui` restores the centred window and default scale. Drag the window to move it; Escape closes it.

## Sound and character celebrations

Version **1.1.0** adds Horde celebration milestones using your supplied sound files:

| Grats after your most recent ding | Sound | Artwork |
| --- | --- | --- |
| **5** | A random clip from `sounds/cheer` | The race and gender of the selected voice |
| **10** | A random clip from `sounds/congrats` | The race and gender of the selected voice |
| **15** | `sounds/for_the_horde.mp3`, or `sounds/for_the_horde_rare.mp3` for the rare portrait | The regular or rare Thrall/Sylvanas scene |

Each milestone fires once per ding. Every separate qualifying message from an eligible guildmate counts, including repeated replies and replies from characters already at zero debt. Duplicate delivery of the same chat event counts once. Your own characters, excluded characters, non-guild senders and GratzGuild reports do not contribute.

The counter starts at your next actual level-up and accepts replies for **five minutes (300 seconds)**. This window applies to both debt repayment and celebration milestones. At exactly five minutes, further replies stop counting until your next ding. Like the ledger, the most recent ding's counter and reply window are shared within the guild across your alts. Counts and fired milestones survive reloads and normal logouts; logging in or switching alts does not restart the timer. Previously played milestones are not replayed at login. Replies buffered while the roster is unavailable are judged by their original arrival time and original ding's window, even if processing finishes after the cutoff. Milestones earned in time may finish playing after the window closes.

Sounds appear with a separate transparent character popup, even with the ledger closed. The artwork stays visible for at least five seconds. Rapid milestones queue so their voices and artwork play together without overlapping. A new ding, changing guilds, or disabling celebrations cancels older queued effects. Its small **x** dismisses the current voice and drawing. The drawing itself lets mouse clicks pass through.

Open **Celebrations** or type **`/gg celebrations`** to enable/disable effects, view the counter, reset the popup layout, or use the single **Test popup (male orc)** button. This test always uses the regular male-orc artwork and never changes debt, counters, milestone flags or collection unlocks.

Whenever the main interface is open, a purple **Popup placement** guide appears. Drag its header to position all three milestones; drag its bottom-right corner to resize them. Position and size are saved. The default is **75%** size, slightly above and to the right of screen centre. The guide hides while a popup is playing so its outline and instructions do not cover the drawing. It returns after playback if the interface is still open. Closing the interface hides the guide while real celebrations continue to use that location.

Open **Collection** or **`/gg collection`** to see all **22** regular and rare entries. Locked entries conceal their drawings, names, race and gender, and show only a generic title and the grats requirement. The collection does not show rare proc chances. A drawing unlocks permanently when that exact variant appears in a real celebration, and can then be viewed without playing a sound. Unlocks are shared across your alts, survive reloads, and are independent of guild membership. Tests and cancelled or disabled effects do not unlock anything. Collection recording begins with this version; earlier displays were not saved. Reduced motion also disables the popup fades. Playback uses WoW's **Master** sound channel and respects the game's sound settings.

All ten Horde race/gender combinations have distinct artwork. Blood-elf audio is represented by **Skyborne** blue elves, using your reference's silver hair, golden eyes and pale arcane markings. The cowboy orc, blushing effeminate male tauren and glamorous Skyborne woman have the requested individual personalities. The finale follows your supplied raised-arms poster pose.

The catalog contains **21 unique cheer clips**, **24 unique congratulations clips**, and regular and rare Horde finales. The supplied `for_the_horde_rare.m4a` is preserved in `sounds/` and converted to `for_the_horde_rare.mp3` for playback. Two byte-identical duplicate congratulations files remain in your folder but are excluded from random selection so they do not get extra weight. If you add more supported voice files later, rebuild `SoundCatalog.lua` with `python tools/build_sound_catalog.py`; WoW addons cannot enumerate arbitrary folders at runtime.

### Rare portraits

Version **1.1.1** bundles your eleven alternate portraits. Whenever a cheer, congratulations clip or Horde finale is displayed, its matching portrait has an independent **5% chance** to use the rare variant; otherwise it uses the regular portrait. The male-orc test always uses regular artwork. This is a random chance per celebration, rather than a guarantee of exactly five rare pictures in every hundred plays.

The variant is chosen once when the popup starts, so refreshing the ledger does not reroll it. Queued effects that are cancelled before displaying do not roll. The Collection tab records regular and rare variants separately. Popup captions use encouraging character-themed messages, such as "You da best, mon!", instead of race and gender labels. Both Skyborne variants map to the blood-elf voices. Cheer and congratulations voices stay the same for rare portraits; the rare Horde scene instead plays your supplied **`for_the_horde_rare.mp3`** clip. The regular Horde scene keeps its original sound. The selected clip's length controls popup timing.

Original supplied PNGs and game-compatible textures are saved under `Media/Celebrations`, with the suffix **Rare**. Source filenames, dimensions and checksums are recorded in `RareArtworkManifest.json`. The pictures retain their proportions and supplied backgrounds. `tools/package_rare_art.py` can rebuild the textures from a directory containing your original files.

## Gratz Debt

- Each level you gain adds one debt to every guild character, including offline members. Your own known alts and names you enter in the exclusions field are exempt.
- Each separate grats-style message received from a current guildmate **during the five minutes after your latest ding** repays one of their debt. Repeated identical messages count separately, but a single message with several grats words counts once.
- Unpaid debt remains when the window closes. A new level-up opens another five-minute window, during which replies can repay accumulated debt. Manual balance corrections and forgiveness remain available.
- Debt stops at zero. Extra congratulations do not buy credit for future levels.
- Any matching message counts, including congratulations intended for someone else. The sender does not need to mention you.
- The ledger, balances and announcement selections are shared across your alts in the same guild. Guilds and guild realms have separate ledgers. These are local account SavedVariables, not synchronization between different accounts or computers.
- The addon starts at your current level and does not invent historical debt. A newly discovered guildmate starts at zero; a returning guildmate resumes their preserved balance. Departed characters retain history but do not receive charges or appear in reports.
- Your own alts are identified when you log into them with GratzGuild enabled. Add unvisited alts as `Name-Realm`, one per line, in Settings. A subsequently recognized own alt has any mistaken debt cleared.
- Announcement checkboxes control reporting only. Unchecking a guildmate does not stop their debt tracking. All new eligible guildmates start selected.

The addon counts chat **your logged-in character receives**, including guild, officer, whisper, say, yell, party, raid, instance, custom channels, community channels and player emotes. It cannot observe distant say/yell, inaccessible officer chat, messages while logged out, or chat while disabled. Battle.net whispers count only when a WoW character GUID reliably matches a guild member. It does not infer characters from Battle.net account display names.

Use **Edit** beside a guildmate to correct or forgive a balance, with confirmation. **Recent activity** displays the latest 80 recorded level-ups, repayments and corrections. If the roster is late, relevant level-ups and chat are retained and processed in arrival order when a complete roster arrives.

## Recognition and automatic congratulations

Built-in English congratulations include `grats`, `gratz`, `congrats`, `congratz`, `congratulations`, `congratulation`, `congratulationz`, `congratzs`, `gratzs`, `gratulations`, `gratulation`, `gz`, `grz`, `grattis`, `gratzies`, `gratsies`, `gratzor`, `gratzors`, `gratsz`, `congratsz`, `congrates`, `congratzies`, `cgrats`, `cgratz`, `congradulations`, `congraduations`, `congradz`, `cg` and `gratez`.

Case, punctuation and stretched repeated letters are accepted, such as **GRAAAATZZZ!!!**. Whole words are matched, so `gzipped` and `disgrats` do not count. Item links, textures and atlas labels are ignored. Add other languages or phrases one per line under **Extra grats phrases**. The phrase tester uses the same matching rules as actual chat and previews unsaved phrase edits.

When another guildmate says a standalone **ding** word or the phrase **BIG DINGUS** in any monitored channel, auto-grats replies in **guild chat**. `Ding!`, `Diiiing 42` and `ding, finally!` count. `standing` and `dinghy` do not. Replies have a 30-second cooldown per sender; debt repayments have no cooldown. Your own characters' messages, GratzGuild reports and messages containing grats words never trigger a reply. Old dings buffered for more than 30 seconds are not automatically answered.

Message placeholders:

| Message | Placeholders | Example |
| --- | --- | --- |
| My level-up | `{level}`, `{name}` | `Ding! {name} is now level {level}!` |
| Auto-grats | `{name}` | `Gratz, {name}! For the Horde!` |

Messages are limited to 255 UTF-8 bytes without splitting characters. Long debt reports split into multiple messages, each carrying the `[GratzGuild]` prefix. Reports are sorted by debt descending, then name, and sent at 1.5-second intervals. You can cancel the remainder. Changing guilds cancels queued messages. Guild-rank restrictions or client API failures are reported locally and stop the queue.

## Verification

The included test harness executes the actual Lua files under **Lua 5.1** and a strict mocked WoW API. It verifies tracking, matching, event deduplication, delayed rosters, alts, guild changes, chat queuing, permissions, report splitting, settings callbacks, scrolling and smaller-screen sizing.

Run `python tests/test_gratzguild.py -v` from this addon folder. Tests need the Python `lupa` package with its `lua51` runtime; this workspace can also use the installed runtime beside PetMaxxing. **Neither Python nor PetMaxxing is required to use the addon in WoW.**

The previews in `tests/output` are approximations rendered from the actual Lua UI layout, using substitute desktop fonts and mocked data. They are not in-game screenshots. The packaged artwork has been checked for power-of-two dimensions, uncompressed 32-bit TGA encoding and transparency.

### Performance regression checks (1.3.2)

The Lua 5.1 suite includes 67 tests. With a 1,000-member mocked roster, the measured workloads changed as follows:

| Workload | Before | After |
| --- | --- | --- |
| 60 simulated seconds after a ding, window closed | 240 sorts, 60 report rebuilds; 1.296 s CPU | Zero sorts or rebuilds; under 0.001 s CPU |
| Burst of 100 roster events, offline filter enabled | 100,000 member reads; 0.787 s CPU | 1,000 member reads in one scheduled scan; 0.008 s CPU |
| 10,000 ordinary public chat messages | 300,000 normalization calls; 0.866 s CPU | 10,000 normalization calls; 0.105 s CPU |

The roster workload includes a 0.25-second simulated advance after the event burst to run the scheduled scan. These are desktop mock timings, not in-game frame times; operation counts are the deterministic regression checks. Actual stuttering still needs an in-game comparison during normal play, busy chat and the five minutes after a level-up, with the window both open and closed. Verify offline members and popup/audio playback using the steps below.

### In-game smoke test still required

1. Confirm GratzGuild loads without Lua errors and `/gg` opens all five tabs. Check transparency, fonts, minimap dragging, scrollbars and saved position at your UI scale.
2. Confirm the roster includes offline members. Gain a real level: expect one customized guild announcement and one debt for every eligible guild character.
3. Ask a guildmate with debt to send two separate grats messages in different channels. Each should repay one, stopping at zero.
4. Have another guildmate say `ding` in a received whisper or say message. Expect your customized guild reply, with a 30-second per-sender cooldown. Your own `Ding!` must not trigger it.
5. Review and send a small selected debt report; check the guild text matches the preview. Verify cancellation with a longer report.
6. Log out normally, log into an alt in the same guild and verify the shared ledger and selections persist.
7. Open Celebrations and test the male-orc popup. Move and resize the placement guide, close and reopen the interface, and verify the layout persists. Check dismissal and reduced motion. Real 5/10/15 milestones should use that same layout.
8. Within five minutes of an actual ding, receive 5, 10 and 15 separate qualifying messages from guildmates. Expect one cheer, one congratulations clip and the Horde finale, respectively. Repeat grats at zero debt within the window to check that the celebration counter keeps increasing. After five minutes, replies must change neither debt nor the counter. Your next ding must reset the counter and reopen the window.
9. When the rare Horde portrait appears, verify it plays the new rare clip. The normal Horde portrait must still use the original clip. Tests must never roll rare artwork or unlock collection entries.

## Files and artwork

`Core.lua` contains the debt and matching rules; `Main.lua` handles game events and chat delivery; `UI.lua` builds the interface. `Celebrations.lua` handles milestone counts, paired audio/art popups and playback queuing; `SoundCatalog.lua` indexes the supplied clips and their portraits. Persistent data is stored in the account's `GratzGuildDB` SavedVariables.

The built-in image-generation tool created the original illustrations. Their full prompts and asset details are recorded in `Media/ARTWORK.md`. Original transparent PNGs and runtime TGA textures are bundled together. `tools/prepare_art.py` reproduces the texture packaging; `tools/render_preview.py` renders exported layout data for development QA.

The eleven new celebration illustrations are bundled under `Media/Celebrations`, with their exact generation and final-edit prompts in `ArtworkManifest.json`. `tools/package_celebration_art.py` packages these illustrations as game-compatible TGA files and creates the labelled portrait gallery in `tests/output`.
