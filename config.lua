Config = {}

-- Plate carriers available (names must match qb-core Shared.Items)
Config.PlateCarriers = {
    ['heavypc'] = {
        plateType = 'heavy', -- heavy supports 50 armor per plate
        clothing = {
            male   = { drawableCategory = 9, drawable = 76, texture = 10 },
            female = { drawableCategory = 9, drawable = 76, texture = 10 },
        }
    },
    ['lightpc'] = {
        plateType = 'light', -- light gives 25 armor per plate use
        clothing = {
            male   = { drawableCategory = 9, drawable = 75, texture = 0 },
            female = { drawableCategory = 9, drawable = 75, texture = 0 },
        }
    },
}

-- Plate items and their armor values (kept here for easy tuning)
Config.Plates = {
    heavyplate = 50,
    lightplate = 25,
}

-- Optional: progress time (ms) when equipping/unequipping a vest
Config.EquipDuration = 2000

-- (Optional) Items list for documentation / item packs.
-- NOTE: You still need matching entries in qb-core/shared/items.lua with useable=true
Config.Items = {
    {
        name = 'heavypc',
        label = 'Heavy Plate Carrier',
        weight = 1000,
        type = 'item',
        image = 'heavypc.png',
        unique = true,
        useable = true,
        shouldClose = true,
        description = 'Modular vest. Works with heavy plates.',
        info = {}
    },
    {
        name = 'lightpc',
        label = 'Light Plate Carrier',
        weight = 1000,
        type = 'item',
        image = 'lightpc.png',
        unique = true,
        useable = true,
        shouldClose = true,
        description = 'Modular vest. Works with light plates.',
        info = {}
    },
    {
        name = 'heavyplate',
        label = 'Heavy Plate',
        weight = 250,
        type = 'item',
        image = 'heavyplate.png',
        unique = true,
        useable = true,  -- plates are useable
        shouldClose = true,
        description = 'Adds 50 armor when used with a heavy carrier.',
        info = {}
    },
    {
        name = 'lightplate',
        label = 'Light Plate',
        weight = 250,
        type = 'item',
        image = 'lightplate.png',
        unique = true,
        useable = true,  -- plates are useable
        shouldClose = true,
        description = 'Adds 25 armor when used with a light carrier.',
        info = {}
    },
}


-- Progress settings for using plates
Config.PlateUseDuration = 2500         -- ms
Config.PlateUseLabel    = 'Inserting plate...'


-- Progress UI provider: 'ox_lib' (lib.progressCircle) or 'qbcore' (QBCore.Functions.Progressbar) or 'none'
Config.ProgressProvider = 'ox_lib'

-- Vest (carrier) progress settings
Config.VestUseDuration   = 5000
Config.VestEquipLabel    = 'Equipping carrier...'
Config.VestRemoveLabel   = 'Removing carrier...'
-- Do NOT freeze player during vest progress (movement/combat allowed)
Config.VestFreezePlayer  = false

-- Plate progress settings
Config.PlateUseDuration  = Config.PlateUseDuration or 2500
Config.PlateUseLabel     = Config.PlateUseLabel or 'Inserting plate...'
-- Allow cancel while inserting plate?
Config.PlateCancelable   = true
-- Freeze player during plate progress? (set to true if you want more weight to using plates)
Config.PlateFreezePlayer = false



-- Anti-abuse & environment gates
Config.PlateCooldownMs      = 1000     -- per-player cooldown between plate uses
Config.RequireNotInVehicle  = false
Config.RequireNotSwimming   = false
Config.RequireNotDowned     = true     -- uses PlayerData.metadata flags when available
Config.RequireNotCuffed     = true     -- uses PlayerData.metadata flags when available
Config.RequireSpeedBelow    = nil      -- m/s, nil to disable

-- Stored armor model
Config.TypeCaps = { light = 50, heavy = 100 }   -- max stored armor by carrier type
Config.RoundTo  = { light = 25, heavy = 50 }    -- optional rounding increments (nil disables)
Config.ApplyStoredWhenArmorAtOrBelow = 0        -- when equipping a carrier, apply stored armor if current armor <= this threshold

-- Death behavior
Config.ClearStoredOnDeath   = false    -- if true, when the player dies, the equipped carrier's stored armor is cleared

Config.RequireEquippedToPlate = false


-- Allow applying armor while swimming? (affects plate use and stored-armor apply on equip)
Config.AllowApplyWhileSwimming = true