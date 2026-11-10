# AGENTS.md — Development Guide for WoW Forever (Client 1.60 / Interface 16001)

This guide documents the architecture, APIs, constraints, and documentation sources for developing addons for **World of Warcraft: Forever** and this repository (**ImprovedForever**).

---

## 1. Environment & Architecture Overview

- **Game Client:** World of Warcraft: Forever (Client version `1.60.x`, TOC `## Interface: 16001`).
- **Engine Heritage:** Built on the modern client branch (Retail/Mainline FrameXML and security architecture), *not* legacy Classic (1.12) or Wrath (3.3.5).
- **Modern Namespaces:** Legacy globals (`GetSpellInfo`, `GetItemInfo`, `UnitAura`, `GetMerchantItemInfo`) are deprecated or removed. Always use modern namespaces:
  - `C_Spell` (e.g., `C_Spell.GetSpellCooldown`, `C_Spell.GetSpellInfo`)
  - `C_Item` (e.g., `C_Item.GetItemCooldown`, `C_Item.GetItemInfo`)
  - `C_ActionBar` (e.g., `C_ActionBar.GetActionCooldownDuration`, `C_ActionBar.HasAction`)
  - `C_CurveUtil` & `Enum.LuaCurveType`
- **Client Version Traps:** Many legacy addons branch logic using `select(4, GetBuildInfo()) >= 100000` to detect modern Retail APIs. In *Forever*, `GetBuildInfo()` returns build version `16001`, which breaks checks expecting standard 6-digit retail build numbers. Always feature-detect API functions (`if C_Spell and C_Spell.GetSpellCooldown then ...`).

---

## 2. Security Restrictions & Combat Lockdown

### Secret Values (`issecretvalue`)
In Client 1.60 / modern client architecture, Blizzard protects real-time combat metrics (cooldowns, health, cast times, durations) with the **Secret Values** system to restrict automated decision-making.

- **What it is:** A secret value is an opaque black box containing a number, string, or boolean.
- **The Restriction:** Unsecure / tainted addon code cannot perform arithmetic (`val + 1`), comparisons (`val > 0`, `val <= GCD_MAX`), or string concatenation/formatting (`tostring(val)`) on a secret value. Doing so throws a fatal Lua error:
  ```text
  attempt to compare local 'duration' (a secret value)
  attempt to perform arithmetic on a secret value
  ```
- **Checking for secrets:**
  ```lua
  local function Secret(v)
      return type(issecretvalue) == "function" and issecretvalue(v)
  end
  ```
- **Working with Duration & Cooldown Objects:**
  Instead of reading raw numbers in combat, pass native duration objects directly to native Blizzard UI frames that support them:
  - `C_ActionBar.GetActionCooldownDuration(actionSlot, [includeGCD])` returns a duration object.
  - `cooldownFrame:SetCooldownFromDurationObject(durationObject)` allows the native C++ engine to render swipes and progress without exposing the secret numbers to Lua.

### UI Taint Prevention
- **Never modify properties of Blizzard frames directly** (`SetAlpha`, `Hide`, `SetPoint` on native frames taints them and triggers `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` when gamepad windows close).
- **Use Animations / Fades:** Use `IF.Focus.Fade(region, true)` instead of `region:Hide()` or `region:SetAlpha(0)`.
- **Do not add frames to `RightManagedFrameContainer:AddManagedFrame`:** This taints objective tracker layout.
- **Gamepad focus:** Never take gamepad button presses directly while a native game window is focused, as this breaks `SetPreferredGamepadInteractTarget`.

---

## 3. Documentation Sources & API Reference

### Extracting Official Client Code
The most authoritative documentation is the extracted game code from the client itself:
1. In-game, run:
   ```text
   /console exportInterfaceFiles code
   /console exportInterfaceFiles art
   ```
2. Extracted files will be generated in your game folder:
   - `/Applications/World of Warcraft/_forever_/BlizzardInterfaceCode/`
   - `/Applications/World of Warcraft/_forever_/BlizzardInterfaceArt/`

### Online Repositories & Tools
- **Ketho/BlizzardInterfaceResources (GitHub):** Automated dumps of FrameXML, global variables, and widget templates across Blizzard client versions.
- **Wago.tools:** Inspect client database tables (DBCs / DBFilesClient), spell tables, items, and assets for build 1.60+.
- **Townlong-Yak (Townlong-Yak.com):** Comprehensive FrameXML and Blizzard UI documentation search.
- **Warcraft Tavern & Wowpedia (API Documentation):** Up-to-date documentation for `C_*` namespaces and modern widget methods (`CooldownFrameTemplate`, `ScriptRegion`, etc.).

---

## 4. ImprovedForever Project Architecture

The addon is modular, split into core and feature modules:

| Directory | Purpose |
|---|---|
| `ImprovedForever/` | Core framework: bindings, input handling, focus management (`IF.Focus`), item valuation (`IF.ItemValue`), and native overrides. |
| `ImprovedForever_Immersion/` | Action bar HUD (`GamepadBar.lua`), Unit frames (`UnitFrames.lua`), Buff & Cooldown rows (`BuffTimeline.lua`), NPC dialogs. |
| `ImprovedForever_Wheel/` | Radial ring menus for items, spells, emotes, and gear. |
| `ImprovedForever_QuestTracker/` | Fork of Blizzard Objective Tracker customized for gamepad navigation. |
| `ImprovedForever_Auction/` | Custom auction interface and price valuation. |
| `ImprovedForever_Journal/` | In-game travel log, road notes, and fight summaries. |
| `ImprovedForever_Wiki/` | In-game encyclopedia using synced client data. |
| `tools/` | Python data sync scripts, asset generators, and packaging tools. |

---

## 5. In-Game Debugging & Diagnostic Probes

### Enabling Error Reporting
Because WoW suppresses script errors by default, turn on error dialogs:
```text
/console scriptErrors 1
```
To enable taint logging:
```text
/console taintLog 1
```
*(Remember to turn taint logging off with `/console taintLog 0` before long play sessions).*

### Addon Probes
ImprovedForever has built-in diagnostic commands that dump state into `SavedVariables`:
- `/if padprobe` — Dumps action bar button states, actions, icons, and cooldown queries into `ImprovedForeverDB.padProbe`.
- `/if tlprobe` — Runs a 10-second trace recording cooldown states, durations, and secret status into `ImprovedForeverDB.timelineProbe`.
- `/reload` — Commits the `SavedVariables` to disk.

### SavedVariables Location (macOS)
```text
/Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/SavedVariables/ImprovedForever.lua
```
Per-character data:
```text
/Applications/World of Warcraft/_forever_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/ImprovedForever.lua
```
