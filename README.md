# gravvy\_armor – Config‑Only README (for non‑coders)

This project is licensed under the GNOSL-1.2.  
See [LICENSE.md](LICENSE.md) for full terms.

This guide explains **everything you can change by editing only `config.lua`**. You do **not** need access to the client or server scripts to:

* Add or tune **plate carriers** (with their own max durability)
* Add or tune **armor plates** (how much armor they give, cooldowns, rate‑limits)
* Add or tune **repair items** (how much durability they restore, which carriers they can repair)
* Adjust **damage→durability** scaling, **progress/labels/durations**, **gates** (like dead/cuffed), and **diminishing returns** (carrier max drops after repairs)

> **Important:** The names you put in `config.lua` for items must match the item names in your framework (qb‑core or your inventory). If an item isn’t defined on the server, it won’t exist—even if you put it in the config.

---

## 1) Where the data lives

* **Carriers** live in `Config.PlateCarriers`.
* **Armor plates** live in `Config.Plates`.
* **Repair items** live in `Config.RepairItems`.
* **Damage model, UI/labels, gating rules, cooldowns, diminishing returns** live in their own sections (see below).

The script stores some info **inside each carrier item** (in `item.info`), created automatically the first time you use/equip it:

* `info.carrierId` – unique ID for that item (used to track the equipped carrier)
* `info.max0` – the original factory **max durability** from config (doesn’t change)
* `info.max` – the **current max durability** (can shrink due to diminishing returns)
* `info.durability` – the **current durability** (goes up/down)

You don’t need to touch these fields; they are managed for you.

---

## 2) Quick start: add new stuff with only `config.lua`

### A) Add a new plate carrier

```lua
Config.PlateCarriers['uberpc'] = {
    plateType     = 'heavy',   -- must match a plate’s type
    maxDurability = 2000,      -- factory max (per-item)
    -- Optional per-carrier resistances (affects durability loss on damage):
    -- resist = { RIFLE = 0.9, EXPLOSIVE = 1.1 },
    -- headshotExtra = 0.10,
}
```

**Notes**

* `plateType` must be `'light'` or `'heavy'` (or whatever types your plates use).
* Anyone can now equip this carrier and use plates with matching type.

### B) Add a new armor plate

```lua
Config.Plates['swatplate'] = {
    type       = 'heavy',  -- must match a carrier’s plateType
    armor      = 75,       -- how much armor it gives (clamped to 100 max armor)
    cooldownMs = 7000,     -- optional: per-item cooldown per player
    limit      = { windowMs = 60000, maxUses = 2 } -- optional: rate-limit over time
}
```

**Notes**

* No client/server edits needed. The plate will auto‑register as a usable item.

### C) Add a new repair item (repairs carriers in inventory)

```lua
Config.RepairItems['kevlarsheets'] = {
    value      = 150,     -- durability restored **per unit** in the stack
    appliesTo  = 'any',   -- 'light' | 'heavy' | 'any'
    cooldownMs = 3000,    -- optional
    limit      = { windowMs = 60000, maxUses = 5 } -- optional
}
```

**How repair stacks work**

* If a carrier needs 7 sheets to fully repair but your stack has 13, it will **consume only 7** and leave **6** in the stack.
* If there is less in the stack than needed, it will use what’s there and repair partially.

---

## 3) Diminishing returns (max durability shrinks after repairs)

When enabled, every repair lowers the **current max durability** (`info.max`) of that carrier to encourage replacement.

```lua
Config.RepairDiminish = {
  enabled             = true,      -- turn system on/off
  mode                = 'percent', -- 'percent' or 'flat'
  percent             = 0.05,      -- 5% of current max per apply (if mode='percent')
  flat                = 0,         -- points per apply (if mode='flat')
  minMaxFloorPercent  = 0.40,      -- do not let max drop below 40% of factory max (info.max0)
  applyPerItem        = false,     -- false = apply once per repair **action**; true = once per **unit** consumed
  perUseCap           = nil        -- optional: cap the max loss per apply (points)
}
```

**Tips**

* **Gentle decay:** `percent = 0.03`, `minMaxFloorPercent = 0.50`.
* **Aggressive decay:** `percent = 0.08`, `minMaxFloorPercent = 0.35`.
* **Per‑item penalty:** set `applyPerItem = true` to penalize big stacks more.
* To **disable** the system, set `enabled = false`.

---

## 4) Damage → durability model (when players take damage)

Tweak how incoming damage reduces carrier **durability** (not player armor). These scales multiply together.

```lua
Config.DamageModel = {
  globalScale = 1.0,
  weaponClassScale = {
    PISTOL    = 0.9,
    SMG       = 1.0,
    RIFLE     = 1.15,
    SHOTGUN   = 1.35,
    SNIPER    = 1.50,
    EXPLOSIVE = 2.00,
    MELEE     = 0.35,
    ANIMAL    = 0.25,
    FIRE      = 0.50,
    FALL      = 0.10,
    OTHER     = 1.00
  },
  hitZoneScale = {
    HEAD  = 1.60,
    UPPER = 1.00,
    LOWER = 0.85,
    LIMB  = 0.60,
  },
  headshotExtra = 0.25,            -- extra multiplier if the hit is flagged as headshot
  clampPerHit   = { min = 0, max = nil },
  minFinalLoss  = 1                -- minimum durability lost per registered hit
}
```

**Per‑carrier resistances** (optional) can be added on each carrier:

```lua
Config.PlateCarriers['heavypc'] = {
  plateType = 'heavy',
  maxDurability = 1500,
  resist = { MELEE = 0.85, EXPLOSIVE = 0.9 },
  headshotExtra = 0.15
}
```

> If your server doesn’t send weapon class / hit zone details, the system safely falls back to conservative defaults.

---

## 5) Progress bars, labels, and durations

You can edit labels/durations freely:

```lua
Config.VestUseDuration  = 5000
Config.VestEquipLabel   = 'Equipping carrier...'
Config.VestRemoveLabel  = 'Removing carrier...'
Config.PlateUseDuration = 2500
Config.PlateUseLabel    = 'Inserting plate...'

Config.RepairUseDuration = 4000
Config.RepairUseLabel    = 'Repairing carrier...'
```

**About progress UIs**

* If **ox\_lib** is installed and running, the script shows an ox\_lib progress bar.
* If ox\_lib is **not** running, actions still work but will feel **instant** (no bar) regardless of these settings.

---

## 6) Cooldowns, rate limits, and gates

### Global plate cooldown (between any two plates)

```lua
Config.PlateCooldownMs = 1000  -- 1 second between any plate uses
```

### Per‑plate cooldown and rolling limits

Already shown in the plate examples (`cooldownMs`, `limit = { windowMs, maxUses }`).

### Gameplay gates (when plates/repairs are allowed)

```lua
Config.RequireEquippedToPlate = true
Config.AllowApplyWhileSwimming = true

Config.RequireNotInVehicle = false
Config.RequireNotSwimming  = false
Config.RequireNotDowned    = true
Config.RequireNotCuffed    = true
```

### Repair targeting behavior

```lua
Config.AllowRepairEquippedOnly = false   -- true = only repair the equipped carrier
Config.RepairPreferEquipped    = true    -- Prefer the equipped carrier if multiple are damaged
```

---

## 7) Reference: All configurable keys (cheat sheet)

**Carriers** – `Config.PlateCarriers[name]`

* `plateType` (string): `'light'|'heavy'|...`
* `maxDurability` (number): factory max
* `resist` (table, optional): e.g., `{ RIFLE = 0.9 }`
* `headshotExtra` (number, optional): extra multiplier on headshots

**Plates** – `Config.Plates[name]`

* `type` (string): must match a carrier’s `plateType`
* `armor` (number): armor granted (player armor, up to 100 total)
* `cooldownMs` (number, optional)
* `limit.windowMs` + `limit.maxUses` (optional)

**Repair items** – `Config.RepairItems[name]`

* `value` (number): durability restored **per item**
* `appliesTo` (string): `'light'|'heavy'|'any'`
* `cooldownMs` (number, optional)
* `limit.windowMs` + `limit.maxUses` (optional)

**Diminishing returns** – `Config.RepairDiminish`

* `enabled` (bool)
* `mode` (`'percent'|'flat'`)
* `percent` / `flat`
* `minMaxFloorPercent` (0.0–1.0)
* `applyPerItem` (bool)
* `perUseCap` (number or `nil`)

**Damage model** – `Config.DamageModel`

* `globalScale`, `weaponClassScale`, `hitZoneScale`, `headshotExtra`, `clampPerHit`, `minFinalLoss`

**UI/Progress**

* `VestUseDuration`, `VestEquipLabel`, `VestRemoveLabel`
* `PlateUseDuration`, `PlateUseLabel`
* `RepairUseDuration`, `RepairUseLabel`

**Gates & Behavior**

* `PlateCooldownMs`
* `RequireEquippedToPlate`, `AllowApplyWhileSwimming`
* `RequireNotInVehicle`, `RequireNotSwimming`, `RequireNotDowned`, `RequireNotCuffed`
* `AllowRepairEquippedOnly`, `RepairPreferEquipped`

**Defaults**

* `Config.Defaults.MaxDurability` – fallback if a carrier doesn’t set `maxDurability`

---

## 8) Balancing tips

* Think of **carrier max** as its “life expectancy.” High max means more repairs before it bottoms out. Lower max means quicker turnover.
* Use **diminishing returns** to prevent infinite maintenance: start around 5% per action (`percent = 0.05`) with a 40–50% floor.
* Keep **light** carriers at lower max (e.g., 700–900) and **heavy** carriers higher (1200–1600+).
* For plate armor, common values are `25` for light plates and `50` for heavy plates; sniper/shotgun durability loss can be 1.35–1.5x.
* Set repair item `value` relative to your economy (e.g., if a heavy carrier has 1500 max, `value = 150` makes \~10 sheets from zero to full when new).

---

## 9) Troubleshooting (config‑only)

**“Plate doesn’t fit this carrier.”**
The plate’s `type` doesn’t match the carrier’s `plateType`.

**“This carrier is destroyed and can no longer be equipped.”**
Its durability hit **0**. Repair it (if your rules allow) or get a new carrier.

**“No damaged carrier found to repair.”**
Either nothing is damaged, or `appliesTo` (on the repair item) doesn’t match any damaged carriers you have.

**“Item not found” or nothing happens when using an item.**
Make sure the item **exists** in your server’s item list with the **exact same name** you used in `config.lua`.

**Progress bars don’t show.**
Your server probably isn’t running **ox\_lib**. Repairs/plates will still work but apply instantly.

**Max seems stuck low.**
Diminishing returns reduce `info.max`. That’s intended. Get a **new carrier** to reset to `info.max0` (factory max).

---

## 10) Migration notes (from older versions)

* If you previously used a single `Config.MaxDurability`, you can keep it under `Config.Defaults.MaxDurability`. New carriers should set their own `maxDurability`.
* Existing carrier items in player inventories will automatically get `carrierId`, `max0`, `max`, and `durability` the first time they’re touched by the script.

---

## 11) Example: minimal working config

```lua
Config = {}

Config.PlateCarriers = {
  lightpc = { plateType = 'light', maxDurability = 800 },
  heavypc = { plateType = 'heavy', maxDurability = 1500 },
}

Config.Plates = {
  lightplate = { type = 'light', armor = 25, cooldownMs = 3000 },
  heavyplate = { type = 'heavy', armor = 50, cooldownMs = 5000, limit = { windowMs = 60000, maxUses = 2 } },
}

Config.RepairItems = {
  kevlarsheets = { value = 150, appliesTo = 'any', cooldownMs = 3000 },
}

Config.Defaults = { MaxDurability = 1000 }

Config.RepairDiminish = {
  enabled = true,
  mode = 'percent',
  percent = 0.05,
  minMaxFloorPercent = 0.4,
  applyPerItem = false,
}

Config.DamageModel = {
  globalScale = 1.0,
  weaponClassScale = { PISTOL=0.9, SMG=1.0, RIFLE=1.15, SHOTGUN=1.35, SNIPER=1.5, EXPLOSIVE=2.0, MELEE=0.35, ANIMAL=0.25, FIRE=0.5, FALL=0.10, OTHER=1.0 },
  hitZoneScale = { HEAD=1.6, UPPER=1.0, LOWER=0.85, LIMB=0.6 },
  headshotExtra = 0.25,
  clampPerHit = { min = 0, max = nil },
  minFinalLoss = 1,
}

Config.VestUseDuration  = 5000
Config.VestEquipLabel   = 'Equipping carrier...'
Config.VestRemoveLabel  = 'Removing carrier...'
Config.PlateUseDuration = 2500
Config.PlateUseLabel    = 'Inserting plate...'
Config.RepairUseDuration = 4000
Config.RepairUseLabel    = 'Repairing carrier...'

Config.PlateCooldownMs       = 1000
Config.RequireEquippedToPlate = true
Config.AllowApplyWhileSwimming = true
Config.RequireNotDowned      = true
Config.RequireNotCuffed      = true
Config.AllowRepairEquippedOnly = false
Config.RepairPreferEquipped    = true
```

---

### You’re done!

If you can edit `config.lua`, you can control almost everything about carriers, plates, repairs, damage scaling, and diminishing returns without touching code. If you need new items created in the framework, ask your server owner to add them with the **exact names** you used in the config.
