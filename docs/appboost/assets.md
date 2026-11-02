# Assets (paths relative to repo root)

- Logos: `dist/logos/*.png` (per module), `dist/logos/ImprovedForever.png`, `tools/addon_logo.png`, `dist/core_logo_preview.png`
- Feature screenshots (v0.6.0): `dist/media/v060/` (auction_buy, auction_sell, junk_detroy, junk_config, wheel_config, controller_config, vibration_config, peek_config, gathering, gathering_config)
- Feature squares: `dist/media/Square_*@1x.png` (Auction House, Gathering Labels, Junk, Peek Map, Quest Tracker, Vibration, Wiki, Wheel, Fishing, Immersion x4)
- Module icons: `dist/media/Icon_*@1x.png`, `dist/media/Addon_icon@1x.png`
- Fishing: `dist/media/Fishing.gif`, `Fishing_small.gif`, `Fishing_2mb.gif`, `Fishing_Mode.png`, `Fishing_Collection.png`
- CurseForge images: `dist/cf/` (journal, fishing, immersion)
- README images referenced as `media/*.webp` (wheel, vibration, auction-house, wiki, junk, quest-tracker, peek-map, gathering-labels); folder not found in the glob: unknown.
- CurseForge descriptions: `dist/curseforge/{Fishing,Journal,Immersion}.md`
- Videos: none found.

## Campaign media (made 2026-10-26, real in-game, local only: `dist/` is git-ignored)

Originals are in `~/Downloads` (4K, 60 fps, too big to upload); the 1080p, 30 fps copies below are made for posting.
- `dist/media/campaign/logout-scene-1080.mp4`: 17 s, the Camp module's logout scene (HUD gone, black bars, the camera cuts, "Logging out, Leaving in 0:08", the day told back from the Journal). Original `~/Downloads/logout-scene.mp4`.
- `dist/media/campaign/camping-scene-1080.mp4`: 72 s, the campfire scene (Welcoming Campfire countdown, the day told back as subtitles). Original `~/Downloads/camping-scene.mp4`. No sound track.
- `dist/media/campaign/camping-scene-30s.mp4`: 30 s cut of it for Threads (1080p, 7 MB): 0 to 6 s the Camping wheel and the fire, a fade, then 26 to 50 s of the scene (subtitles, camera cuts, countdown 0:40 to 0:16).
- `dist/media/campaign/destroy-and-loot-1080.mp4`: 9 s, the Junk module's Destroy panel at the loot window with full bags. Original `~/Downloads/destroy-and-loot.mp4`.
- `dist/media/campaign/wheel-camping.png`: Camping wheel (Basic Campfire Kit, Fish Bowl), 2000 px wide.
- `dist/media/campaign/wheel-consumables.png`: Consumables wheel mid-fight, 2000 px wide.
- Not released yet: the Camp module (0.1.0) has no CurseForge project or tag. Don't link it until it does.

## Frames from the long recordings (2026-10-26, local only)

Sources (on the Mac, 3 to 20 GB each, not in the repo): `~/Desktop/CleanShot 2026-10-20 at 23.44.22.mp4` (camp scene, 4.8 min), `CleanShot 2026-10-22 at 23.19.52.mp4` (Tirisfal leveling, 27 min), `CleanShot 2026-10-23 at 08.21.08.mp4` (long; mostly desktop windows, not usable), `CleanShot 2026-10-23 at 08.54.16.mp4` (questing, ends in the logout scene).
- `dist/media/campaign/frames/v1_01.jpg` to `v4_10.jpg`: ten full-size (3838x2160) frames per recording, taken at even spacing (v1 = 20 Oct, v2 = 22 Oct, v3 = 23 Oct 08.21, v4 = 23 Oct 08.54). Good ones: v1_06 (character at a campfire), v2_04 (bags open at a campfire), v2_09 (Destroy window), v1_01 to v1_04 and v1_08 (camp scene shots). The `v3_*` frames show desktop windows (Claude, Battle.net): do not use.
- Social images (made with the social-media skill, scene from `v1_06`): `dist/media/campaign/social/giveaway_square.png` (1080x1080: campfire, "GIVEAWAY", a "2 CODES" badge, no code shown). Spec `giveaway_sq.json` and the scene in `work/`.
- All of `dist/` is git-ignored, so none of these is committed.
- `dist/media/campaign/world-boss-1080.mp4`: 33 s, the last beta day's world boss (Thunderaan, Elwynn Forest, Brackwell Pumpkin Patch, a level 10 character). 1080p, no sound, chat left visible (the user checked: nothing sensitive; it faintly shows an Improved Forever Immersion error line). Original `~/Downloads/world-boss.mp4`. `world-boss-1080-clean.mp4` is the same with the chat blurred.
- `dist/media/campaign/social/launch_giveaway_wide.png`: 1920x1080 collage of the three Immersion screenshots below (left: quest header and NPC dialogue subtitles; right: target header and cast bar in combat) with "ARE YOU PREPARED FOR LAUNCH DAY", the series line "Immersion, Camp and your Journal" and a GIVEAWAY badge ("Codes in the first comment"). No codes in the picture. The two Invite-A-Friend codes are in `dist/media/campaign/social/codes.txt` (git-ignored, local only) for the first comment. Specs `launch_collage.json` and `launch_wide.json`. Square version without codes: `giveaway_square.png`.
- `dist/media/campaign/shots/immersion-cast.png`, `immersion-dialogue.png`, `immersion-combat.png`: full-size (3836x2158) screenshots the user took 2026-10-26 at the Crusader Outpost, Brill and Tirisfal Glades: a Hearthstone cast bar with the quest header, the Executor Zygand dialogue as subtitles, and a Scarlet Missionary fight with the target header and a Shadow Bolt cast bar. Originals on the Desktop (`Pasted 2026-10-26 at 9.4x PM.png`). The collage spec is `dist/media/campaign/social/immersion_collage.json`.
- `dist/media/campaign/fishing-clip.mp4`: the Fishing clip as an mp4 (900x380, 10 s, 0.8 MB), made from `dist/media/Fishing.gif`. For Reddit and Threads, which handle mp4 better than a gif.
- `dist/media/campaign/wheels-pair.png`: the two wheel screenshots side by side (2000x563): Camping wheel and Consumables wheel.
- Every planned post with a picture or clip has it in `media_path` (AppBoost previews it and the executor uploads it): Reddit logout (`logout-scene-1080.mp4`), Reddit fishing (`fishing-clip.mp4`), Facebook Junk (`destroy-and-loot-1080.mp4`), Facebook logout in Dvalin Gaming (`logout-scene-1080.mp4`), Facebook wheels (`wheels-pair.png`), the giveaway (`launch_giveaway_wide.png`), Threads campfire (`camping-scene-30s.mp4`), Threads wheel (`wheel-consumables.png`), Threads logout, bags and fishing.
