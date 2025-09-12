Config = {}

-- Plate carriers available (names must match qb-core Shared.Items)
Config.PlateCarriers = {
    ['heavypc'] = {
        plateType = 'heavy', -- pairs with heavy plates
        clothing = {
            male   = { drawableCategory = 9, drawable = 76, texture = 10 },
            female = { drawableCategory = 9, drawable = 76, texture = 10 },
        }
    },
    ['lightpc'] = {
        plateType = 'light', -- pairs with light plates
        clothing = {
            male   = { drawableCategory = 9, drawable = 75, texture = 0 },
            female = { drawableCategory = 9, drawable = 75, texture = 0 },
        }
    },
}

-- Plate items and their armor values
Config.Plates = {
    heavyplate = 50,
    lightplate = 25,
}

-- Progress UI provider: 'ox_lib' | 'qbcore' | 'none'
Config.ProgressProvider = 'qbcore'

-- Vest (carrier) progress settings
Config.VestUseDuration   = 5000
Config.VestEquipLabel    = 'Equipping carrier...'
Config.VestRemoveLabel   = 'Removing carrier...'
Config.VestFreezePlayer  = false

-- Plate progress settings
Config.PlateUseDuration  = 2500
Config.PlateUseLabel     = 'Inserting plate...'
Config.PlateCancelable   = true
Config.PlateFreezePlayer = false

-- Anti-abuse & environment gates
Config.PlateCooldownMs      = 1000     -- per-player cooldown between plate uses
Config.RequireNotInVehicle  = false
Config.RequireNotSwimming   = false
Config.RequireNotDowned     = true     -- uses PlayerData.metadata when available
Config.RequireNotCuffed     = true     -- uses PlayerData.metadata when available
Config.RequireSpeedBelow    = nil      -- m/s, nil to disable

-- Require a carrier to be equipped to use plates
Config.RequireEquippedToPlate = true

-- Allow applying plates while swimming?
Config.AllowApplyWhileSwimming = true

-- Durability model
Config.MaxDurability = 1000  -- default max when first seen / missing