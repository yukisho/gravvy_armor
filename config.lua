Config = {}

-- Created by Gravvy
-- Licensed under GNOSL-1.2
-- Non-commercial use only • Attribution required

-- Plate carriers (names must match qb-core Shared.Items)
-- Each carrier can define its own maxDurability and optional resistance scales.
Config.PlateCarriers = {
    ['heavypc'] = {
        plateType     = 'heavy',
        maxDurability = 1500,
        maxArmor      = 100,
        -- Optional: carrier-level resistance multipliers (applied after global/weapon/hit-zone)
        -- Keys must match Config.DamageModel.weaponClassScale keys
        resist = {
            MELEE = 0.85,     -- 15% less durability loss vs melee
            EXPLOSIVE = 0.9,  -- 10% less vs explosives
        },
        -- Optional: extra multiplier when headshot is flagged
        headshotExtra = 0.15, -- +15% loss on headshots for this carrier (set 0 to ignore)
    },
    ['lightpc'] = {
        plateType     = 'light',
        maxDurability = 800,
        maxArmor      = 100,
        resist = {
            MELEE = 0.75      -- more fragile vs melee by default? set >1.0 to be weaker, <1.0 to be stronger
        },
        headshotExtra = 0.25,
    },
    ['policepc'] = {
        plateType     = 'heavy',
        maxDurability = 1200,
        maxArmor      = 100,
        resist = {
            MELEE = 0.85,     -- 15% less durability loss vs melee
            EXPLOSIVE = 0.9,  -- 10% less vs explosives
        },
    },
    -- Add new carriers here. Example:
    -- ['uberpc'] = { plateType = 'heavy', maxDurability = 2000, maxArmor = 100, resist = { RIFLE = 0.9 }, headshotExtra = 0.05 }
}

-- Plate items and their stats.
-- cooldownMs: per-item cooldown for a player (optional)
-- limit.windowMs + limit.maxUses: rolling window rate limit (optional)
Config.Plates = {
    ['heavyplate'] = { type = 'heavy', armor = 50, cooldownMs = 1200, limit = { windowMs = 2000, maxUses = 2 } },
    ['lightplate'] = { type = 'light', armor = 25, cooldownMs = 1000, limit = { windowMs = 2000, maxUses = 3 } },
    -- Add new plates here:
    -- ['swatplate'] = { type = 'heavy', armor = 75, cooldownMs = 7000, limit = { windowMs = 60000, maxUses = 2 } }
}

-- Fallback defaults (used if a carrier doesn't specify maxDurability)
Config.Defaults = {
    MaxDurability = 1000,
    ArmorMaximum = 100,
    GlobalScale = 1.0
}

-- Animations
Config.Animations = {
    Vest = {
        on = {
            dict = 'oddjobs@basejump@ig_15',
            clip = 'puton_parachute'
        },
        off = {
            dict = 'skydive@parachute@',
            clip = 'chute_off'
        }
    },
    Plate = {
        on = {
            dict = 'mp_common_miss',
            clip = 'put_away_coke'
        }
    },
    Repair = {
        on = {
            dict = 'clothingshirt',
            clip = 'try_shirt_neutral_c'
        }
    }
}

-- Damage -> durability model (server authoritative)
Config.DamageModel = {
    -- Global scale applied to all incoming durability loss
    globalScale = (Config.Defaults.GlobalScale or 1.0),

    -- Weapon class multipliers. Pick keys you’ll actually send from your client damage hook.
    -- (We keep these text keys to stay readable in configs/scripts.)
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

    -- Hit zone multipliers (applied after weapon class).
    -- The client hook can map bones to these zones and flag headshots.
    hitZoneScale = {
        HEAD    = 1.60,
        UPPER   = 1.00, -- chest/upper torso/upper back
        LOWER   = 0.85, -- abdomen/lower back/hips
        LIMB    = 0.60, -- arms/legs
    },

    -- When the client marks a headshot explicitly, add this extra scale (after hitZoneScale).
    headshotExtra = 0.25,

    -- Clamp per-hit durability loss (after all scales, before carrier resist)
    clampPerHit = { min = 0, max = nil }, -- nil max = no cap

    -- Minimum durability loss to register (after all math & rounding)
    minFinalLoss = 1
}

-- Repair items: use from inventory to restore carrier durability.
-- key = item name in qb-core Shared.Items
-- value:
--   value       = durability restored per use
--   appliesTo   = 'light' | 'heavy' | 'any'  (which carrier types this item can repair)
--   cooldownMs  = optional per-item cooldown
--   limit       = optional rolling window rate limit { windowMs = 60000, maxUses = 5 }
Config.RepairItems = {
    ['kevlarsheets'] = { value = 150, appliesTo = 'any',  cooldownMs = 3000, limit = { windowMs = 60000, maxUses = 5 } },
    ['fiberpatch']   = { value =  80, appliesTo = 'light', cooldownMs = 2000 },
    -- Add more repair items here
}

-- Optional: how max durability shrinks after repairs
Config.RepairDiminish = {
    enabled             = true,      -- turn diminishing returns on/off
    mode                = 'percent', -- 'percent' or 'flat'
    percent             = 0.05,      -- 5% of current max per apply
    flat                = 0,         -- flat points per apply (if mode='flat')
    minMaxFloorPercent  = 0.40,      -- never let max drop below 40% of factory (info.max0)
    applyPerItem        = false,     -- true = shrink once per unit consumed; false = once per repair action
    perUseCap           = nil        -- optional: max amount the max can drop per apply (points)
}

-- Repair progress/UI
Config.RepairUseDuration   = 10000
Config.RepairUseLabel      = 'Repairing carrier...'
Config.RepairCancelable    = true
Config.RepairFreezePlayer  = false

-- Repair behavior
Config.AllowRepairEquippedOnly = false   -- true = only repair the equipped carrier
Config.RepairPreferEquipped    = true    -- if multiple damaged carriers exist, try equipped first

-- Progress/UI
Config.ProgressProvider    = 'qbcore' -- 'ox_lib' | 'qbcore' | 'none'
Config.VestEquipDuration   = 2900
Config.VestUnequipDuration = 1800
Config.VestEquipLabel      = 'Equipping carrier...'
Config.VestRemoveLabel     = 'Removing carrier...'
Config.VestFreezePlayer    = false

Config.PlateUseDuration    = 1000
Config.PlateUseLabel       = 'Inserting plate...'
Config.PlateCancelable     = true
Config.PlateFreezePlayer   = false

-- Gameplay gates
Config.PlateCooldownMs       = 1000        -- global floor between any plate uses (still overridden by per-plate cooldown)
Config.RequireNotInVehicle   = false
Config.RequireNotSwimming    = false
Config.RequireNotDowned      = true
Config.RequireNotCuffed      = true
Config.RequireSpeedBelow     = nil         -- m/s or nil

Config.RequireEquippedToPlate = true
Config.AllowApplyWhileSwimming = true
