local QBCore = exports['qb-core']:GetCoreObject()

-- State
local equippedVest = nil  -- { itemName, carrierId, typeName }
local lastArmor    = -1

-- === Progress UI helper (ox_lib / qbcore / none) ===
local function ShowProgress(label, duration, canCancel, freezePlayer)
    duration     = duration or 2500
    canCancel    = canCancel == nil and true or canCancel
    freezePlayer = freezePlayer == nil and true or freezePlayer

    local provider = (Config and Config.ProgressProvider) or 'ox_lib'

    if provider == 'ox_lib' and lib and lib.progressCircle then
        local ok = lib.progressCircle({
            duration = duration,
            label = label or 'Working...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = canCancel,
            disable = {
                car    = freezePlayer and true or false,
                combat = freezePlayer and true or false,
                move   = freezePlayer and true or false,
                mouse  = false,
            }
        })
        return ok and true or false
    elseif provider == 'qbcore' and QBCore and QBCore.Functions and QBCore.Functions.Progressbar then
        local done, success = false, false
        QBCore.Functions.Progressbar('gravvy_kevlar_progress', label or 'Working...', duration, false, canCancel, {
            disableMovement    = freezePlayer and true or false,
            disableCarMovement = freezePlayer and true or false,
            disableMouse       = false,
            disableCombat      = freezePlayer and true or false,
        }, {}, {}, {}, function()
            done = true; success = true
        end, function()
            done = true; success = false
        end)
        while not done do Wait(10) end
        return success
    else
        Wait(duration)
        return true
    end
end

-- === Anim helpers ===
local function LoadAnimDict(dict, timeoutMs)
    timeoutMs = timeoutMs or 2000
    if lib and lib.requestAnimDict then
        return lib.requestAnimDict(dict, timeoutMs)
    end
    RequestAnimDict(dict)
    local endAt = GetGameTimer() + timeoutMs
    while not HasAnimDictLoaded(dict) and GetGameTimer() < endAt do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function PlayVestAnim(label, duration, dict, clip)
    local ped = PlayerPedId()
    local dict = dict or 'clothingtie'
    local clip = clip or 'try_tie_negative_c'
    duration = duration or ((Config and Config.VestEquipDuration) or 5000)

    if LoadAnimDict(dict, 2000) then
        ClearPedSecondaryTask(ped)
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, duration, 49, 0.0, false, false, false) -- 49 upper-body
    end

    ShowProgress(label or 'Working...', duration, false, (Config and Config.VestFreezePlayer) or false)

    if HasAnimDictLoaded(dict) then
        StopAnimTask(ped, dict, clip, 1.0)
        RemoveAnimDict(dict)
    end
end

local function UnequipCarrier(withAnim)
    if not equippedVest then return end
    if withAnim then
        PlayVestAnim((Config and Config.VestRemoveLabel) or 'Removing carrier...', (Config and Config.VestUnequipDuration) or 2000, Config.Animations.Vest.off.dict, Config.Animations.Vest.off.clip)
    end
    local ped = PlayerPedId()
    local PlayerData = QBCore.Functions.GetPlayerData()
    equippedVest = nil
    -- Do not modify armor here (armor persists until damage or plate use)
    -- Just clear server-side equipped state
    local pedArmor = GetPedArmour(ped)

    if pedArmor ~= 0 then
        SetPedArmour(ped, 0)
    end
    
    TriggerServerEvent('gravvy_kevlar:server:setEquipped', nil, nil)
end

-- === Equip/unequip export ===
exports('useVest', function(item, data)
    local ped      = PlayerPedId()
    local itemName = (data and data.name) or (item and item.name)
    if not itemName then return end
    if not (Config and Config.PlateCarriers and Config.PlateCarriers[itemName]) then return end

    -- Toggle off if same item
    if equippedVest and equippedVest.itemName == itemName then
        UnequipCarrier(true)
        return
    end

    -- Ask server to ensure identity + durability and return current info
    local slot = (data and data.slot) or (item and item.slot)
    local srvInfo = nil
    if lib and lib.callback then
        srvInfo = lib.callback.await('gravvy_kevlar:registerCarrier', false, slot)
    end
    if not srvInfo then return end

    local durability = tonumber(srvInfo.durability or 0) or 0
    if durability <= 0 then
        TriggerEvent('QBCore:Notify', 'This carrier is destroyed and cannot be equipped.', 'error', 2500)
        return
    end

    -- Play equip anim
    PlayVestAnim((Config and Config.VestEquipLabel) or 'Equipping carrier...', (Config and Config.VestEquipDuration) or 5000, Config.Animations.Vest.on.dict, Config.Animations.Vest.on.clip)

    equippedVest = {
        itemName  = itemName,
        carrierId = srvInfo.carrierId,
        typeName  = srvInfo.plate_type,
    }

    SetPedArmour(ped, srvInfo.armor)

    -- Inform server about equipped carrier
    TriggerServerEvent('gravvy_kevlar:server:setEquipped', equippedVest.carrierId, equippedVest.typeName)
end)

RegisterNetEvent('gravvy_kevlar:usePlate', function(item, data)
    PlayVestAnim((Config and Config.PlateUseLabel) or 'Inserting plate...', (Config and Config.PlateUseDuration) or 2500, Config.Animations.Plate.on.dict, Config.Animations.Plate.on.clip)
end)

-- Server-triggered equip shim
RegisterNetEvent('gravvy_kevlar:client:useVest', function(item)
    exports['gravvy_kevlar']:useVest(item, item)
end)

-- Absolute set/add armor (unchanged utility)
RegisterNetEvent('gravvy_kevlar:setArmor', function(value)
    local ped = PlayerPedId()
    local v = tonumber(value) or 0
    v = math.max(0, math.min(100, v))
    SetPedArmour(ped, v)
    lastArmor = v
end)

RegisterNetEvent('gravvy_kevlar:addArmor', function(amount)
    local ped = PlayerPedId()
    local cur = GetPedArmour(ped)
    local add = tonumber(amount) or 0
    local new = math.max(0, math.min(100, cur + add))
    SetPedArmour(ped, new)
    lastArmor = new
end)

-- Plate use progress (server awaits)
lib.callback.register('gravvy_kevlar:plateProgress', function(plateName)
    local duration  = (Config and Config.PlateUseDuration) or 2500
    local label     = (Config and Config.PlateUseLabel) or 'Inserting plate...'
    local canCancel = (Config and Config.PlateCancelable) ~= false
    local freeze    = (Config and Config.PlateFreezePlayer) and true or false
    return PlayVestAnim((Config and Config.PlateUseLabel) or 'Inserting plate...', (Config and Config.PlateUseDuration) or 2500, Config.Animations.Plate.on.dict, Config.Animations.Plate.on.clip)
    --return ShowProgress(label, duration, canCancel, freeze)
end)

-- Repair progress callback (mirrors your plate progress pattern)
lib.callback.register('gravvy_kevlar:repairProgress', function(itemName)
    -- Reuse your existing animation/progress helper if you have one:
    local label = (Config and Config.RepairUseLabel) or 'Repairing...'
    local dur   = (Config and Config.RepairUseDuration) or 4000
    if PlayVestAnim then
        --weapons@first_person@aim_idle@p_m_zero@projectile@tear_gas@aim_trans@idle_to_idlerng : aim_trans_high
        return PlayVestAnim(label, dur, Config.Animations.Repair.on.dict, Config.Animations.Repair.on.clip) -- should return true/false
    end

    -- Fallback if you don't have PlayVestAnim defined:
    if GetResourceState('ox_lib') == 'started' then
        local success = lib.progressBar({
            duration = dur, label = label, useWhileDead = false, canCancel = Config.RepairCancelable ~= false,
            disable = { move = Config.RepairFreezePlayer or false }
        })
        return success
    elseif Config and Config.ProgressProvider == 'qbcore' then
        local p = promise.new()
        QBCore.Functions.Progressbar('gravvy_repair', label, dur, Config.RepairCancelable ~= false, false, {
            disableMovement = Config.RepairFreezePlayer or false,
            disableCarMovement = true, disableMouse = false, disableCombat = true,
        }, {}, {}, {}, function() p:resolve(true) end, function() p:resolve(false) end)
        return Citizen.Await(p)
    end
    return true
end)

-- Damage monitor - send durability damage to server
do
    CreateThread(function()
        while true do
            Wait(400)
            local ped = PlayerPedId()
            local cur = GetPedArmour(ped)

            if lastArmor < 0 then
                lastArmor = cur
            elseif cur < lastArmor then
                local dmg = lastArmor - cur
                if equippedVest and equippedVest.carrierId and dmg > 0 then
                    -- Only count actual armor damage
                    TriggerServerEvent('gravvy_kevlar:damageCarrier', equippedVest.carrierId, dmg)
                end
                lastArmor = cur
            elseif cur > lastArmor then
                -- armor increased (plate use, admin, etc.)
                lastArmor = cur
            end
        end
    end)
end

-- Auto-unequip if server says so (destroyed)
RegisterNetEvent('gravvy_kevlar:forceUnequip', function(reason)
    if equippedVest then
        UnequipCarrier(true)
    end
end)

-- Inventory removal watcher: if the exact equipped carrier disappears, unequip
local function equippedCarrierStillPresent(items)
    if not equippedVest or not equippedVest.carrierId then return false end
    for _, it in pairs(items or {}) do
        if it and it.name == equippedVest.itemName then
            local info = it.info or {}
            if info.carrierId == equippedVest.carrierId then
                return true
            end
        end
    end
    return false
end

RegisterCommand('setarmor', function(source, args, raw)
    local amt = tonumber(args[1]) or 0
    amt = math.max(0, math.min(100, amt))
    local ped = PlayerPedId()
    SetPedArmour(ped, amt)
    lastArmor = amt
end, false)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(pd)
    local items = (pd and pd.items) or {}
    if equippedVest and equippedVest.carrierId then
        if not equippedCarrierStillPresent(items) then
            SetTimeout(400, function()
                local pd2 = QBCore.Functions.GetPlayerData()
                local items2 = (pd2 and pd2.items) or {}
                if not equippedCarrierStillPresent(items2) then
                    UnequipCarrier(true)
                end
            end)
        end
    end
end)

-- Fallback poll in case the event misses
CreateThread(function()
    while true do
        Wait(2000)
        if equippedVest and equippedVest.carrierId then
            local pd = QBCore.Functions.GetPlayerData()
            local items = (pd and pd.items) or {}
            if not equippedCarrierStillPresent(items) then
                UnequipCarrier(true)
            end
        end
    end
end)
