# gravvy_kevlar
An advanced, plate-based armor system for QBCore

## Overview
**gravvy_kevlar** adds two carrier items (Light & Heavy) and two plate items (Light & Heavy). Players can **equip a carrier** and **use plates** to raise armor. Each carrier **stores its own armor value** in item metadata and keeps that value synchronized when the player takes damage.

No database required. Supports **ox_lib**, **QBCore Progressbar**, or **no UI** for progress displays—fully configurable.

### Key Features
- **Per-item stored armor** (persists on the carrier via item metadata).
- **Light/Heavy carriers & plates** (25 / 50 armor per plate, configurable via caps).
- **Matching required** (light plates with light carriers, heavy plates with heavy carriers).
- **Use from inventory or hotbar** (no extra UI needed).
- **Auto-unequip on item removal** (and armor set to 0).
- **Equip to re-apply stored armor** (when current armor ≤ your threshold).
- **Anti-abuse safeguards**:
  - Server cooldown + concurrency guard for plate use.
  - Damage sync can **only decrease** stored armor (never increase).
  - Optional “carrier must be equipped to insert plates.”
- **No DB** (metadata only).
- **Escrow-safe**: all logic is protected; buyers get full access to `config.lua`.

---

## Requirements
- **qb-core**
- **qb-inventory**
- **ox_lib** *(optional but recommended if you want the circular progress UI)*

> If you don’t use ox_lib, set `Config.ProgressProvider = 'qbcore'` or `'none'`.

---

## Installation

1) **Drag & drop** the resource folder into your `resources` directory.

2) **Ensure in server.cfg**
   ```cfg
   ensure ox_lib        # if you’re using ox_lib progress UI
   ensure qb-core
   ensure qb-inventory
   ensure gravvy_kevlar
   ```

3) **Items (qb-core/shared/items.lua)**  
   Add (or align) your items so their **names match** what you configure in `config.lua`.
   - Plates must be **stackable**: `unique = false`, **no metadata**.
   - Carriers must be **unique**: `unique = true`.

   Example:
   ```lua
   ['lightpc']    = { name = 'lightpc',    label = 'Light Plate Carrier', weight = 100,  type = 'item', image = 'lightpc.png',    unique = true,  useable = true,  shouldClose = true, description = 'Modular vest with 1 plate slot.' },
   ['heavypc']    = { name = 'heavypc',    label = 'Heavy Plate Carrier', weight = 1500, type = 'item', image = 'heavypc.png',    unique = true,  useable = true,  shouldClose = true, description = 'Modular vest with 2 plate slots.' },
   ['lightplate'] = { name = 'lightplate', label = 'Light Plate',         weight = 250,  type = 'item', image = 'lightplate.png', unique = false, useable = true,  shouldClose = true, description = 'Adds 25 armor with a light carrier.' },
   ['heavyplate'] = { name = 'heavyplate', label = 'Heavy Plate',         weight = 500,  type = 'item', image = 'heavyplate.png', unique = false, useable = true,  shouldClose = true, description = 'Adds 50 armor with a heavy carrier.' },
   ```

4) **Images**  
   Put your PNGs (`lightpc.png`, `heavypc.png`, `lightplate.png`, `heavyplate.png`) in your inventory UI’s images directory.

5) **fxmanifest**  
   This resource should reference `@ox_lib/init.lua` (if using ox_lib) and provide `config.lua` for configuration.

---

## How it Works (Player Flow)

- **Equip a carrier (Use item)**
  - Plays a short (configurable) animation/progress.
  - If the carrier has stored armor and the player’s current armor ≤ your threshold, it **sets armor to the stored value**.
- **Use a plate**
  - Server validates cooldown/concurrency, carrier type, and gates.
  - Adds armor to both the **player** and the **carrier’s stored value**, respecting caps & rounding.
  - If nothing would be gained (e.g., player already at cap or carrier stored is capped), **the plate is not consumed**.
- **Take damage**
  - Client reports new armor; server **only reduces** the carrier’s stored armor (can’t increase via client).
- **Remove a carrier**
  - If the **equipped** carrier is removed from inventory, the script **auto-unequips** and **sets armor to 0**.
- **Death (optional)**
  - If enabled, death will **clear stored armor** on the equipped carrier.

---

## Configuration

Open `config.lua`. You’ll find:

### UI provider & progress
```lua
Config.ProgressProvider = 'ox_lib'   -- 'ox_lib' | 'qbcore' | 'none'
Config.VestUseDuration  = 5000
Config.VestEquipLabel   = 'Equipping carrier...'
Config.VestRemoveLabel  = 'Removing carrier...'
Config.VestFreezePlayer = false

Config.PlateUseDuration  = 2500
Config.PlateUseLabel     = 'Inserting plate...'
Config.PlateCancelable   = true
Config.PlateFreezePlayer = false
```

### Behavior & anti-abuse
```lua
Config.PlateCooldownMs        = 1000
Config.RequireEquippedToPlate = false
Config.ApplyStoredWhenArmorAtOrBelow = 0
Config.AllowApplyWhileSwimming = true

Config.RequireNotDowned = true
Config.RequireNotCuffed = true

Config.ClearStoredOnDeath = false
```

### Type caps & rounding
```lua
Config.TypeCaps = { light = 50, heavy = 100 }
Config.RoundTo  = { light = 25, heavy = 50 }
```

### Carrier/Plate mappings
```lua
Config.PlateCarriers = {
  lightpc = { plateType = 'light' },
  heavypc = { plateType = 'heavy' },
}

Config.Plates = {
  lightplate = 25,
  heavyplate = 50,
}
```

> The item names above must match your item definitions in `qb-core/shared/items.lua`.

---

## Exports & Events

### Export (client)
```lua
-- Toggle equip/unequip of a carrier from your scripts if needed:
exports['gravvy_kevlar']:useVest(item, data)
```

### Server callbacks / events (internal)
- `gravvy_kevlar:server:setEquipped` — track which carrier is equipped.
- `gravvy_kevlar:syncArmorFromClient` — only reduces stored armor on damage.
- `gravvy_kevlar:playerDied` — clears stored on death (optional).
- `gravvy_kevlar:allowApplyStored` — server authorizes stored-armor apply on equip.

---

## Troubleshooting
- **Using a plate does nothing**: Player is at 100 armor or carrier stored is capped.
- **No progress UI**: Set `Config.ProgressProvider = 'qbcore'` or `'none'` if not running ox_lib.
- **Plates don’t stack**: Ensure `unique = false` **and** no metadata on plates.

---

## Performance
- Lightweight, no DB.
- Client sync 500ms; server only touches item metadata and clamps.

---

## Escrow
- The resource is escrowed; you have full access to **`config.lua`** for customization.
- Need a new hook? Open a ticket and we’ll add a safe config or event.
