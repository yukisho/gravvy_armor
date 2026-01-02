-- server.lua
local QBCore = exports['qb-core']:GetCoreObject()

---------------------------------------
-- Helpers & State
---------------------------------------
local lastPlateUseAny     = lastPlateUseAny or {}
local usingPlate          = usingPlate or {}
local equippedCarrier     = equippedCarrier or {}

-- Plate throttles
local lastPlateUseByItem  = lastPlateUseByItem or {}
local plateRollWindow     = plateRollWindow or {}

-- Repair throttles
local lastRepairUseByItem = lastRepairUseByItem or {}
local repairRollWindow    = repairRollWindow or {}

local function Notify(src, msg, typ, time)
    TriggerClientEvent('QBCore:Notify', src, msg, typ or 'error', time or 2500)
end

local function nowMs() return GetGameTimer() end

local function GetPlayerItems(Player)
    return (Player and Player.PlayerData and Player.PlayerData.items) or {}
end

local function FindFirst(Player, itemName)
    local firstSlot, firstItem
    local items = GetPlayerItems(Player)
    for slot, it in pairs(items) do
        if it and it.name == itemName then
            if not firstSlot or slot < firstSlot then
                firstSlot, firstItem = slot, it
            end
        end
    end
    return firstSlot, firstItem
end

local function FindCarrierById(Player, carrierId)
    if not carrierId then return nil end
    local items = GetPlayerItems(Player)
    for slot, it in pairs(items) do
        local info = it and it.info
        if info and info.carrierId == carrierId then
            return slot, it
        end
    end
    return nil
end

-- Prefer per-item dynamic max stored in info.max; fall back to config
local function GetConfigCarrierMax(itemName)
    local entry = Config.PlateCarriers and Config.PlateCarriers[itemName]
    local max   = entry and (entry.maxDurability or entry.max_durability)
    if not max then
        max = (Config.Defaults and Config.Defaults.MaxDurability) or 100
    end
    return tonumber(max) or 100
end

local function GetConfigCarrierArmor(itemName)
    local entry = Config.PlateCarriers and Config.PlateCarriers[itemName]
    -- Prefer per-carrier key `maxArmor`, then legacy aliases, then globals
    local max = entry and (entry.maxArmor or entry.ArmorMaximum or entry.armor_maximum)
    if not max then
        max = (Config.Defaults and Config.Defaults.ArmorMaximum) or 100
    end
    return tonumber(max) or 100
end

local function GetCarrierMaxForItem(it)
    if not it then return 0 end
    local info = it.info or {}
    local maxInfo = tonumber(info.max or info.maxDurability or info.max_durability or 0) or 0
    if maxInfo > 0 then return maxInfo end
    return GetConfigCarrierMax(it.name)
end

local function EnsureCarrierInfo(src, slot, itemName, info)
    local source = src
    info = info or {}
    if not info.carrierId then
        info.carrierId = ('carrier_%d%d'):format(os.time(), math.random(1000, 9999))
    end
    -- Store original (factory) max once
    local cfgMax = GetConfigCarrierMax(itemName)
    if not info.max0 then info.max0 = cfgMax end
    -- Store current max (can shrink with repairs)
    local ped = GetPlayerPed(source)
    local playerArmor = 0
    if source and type(source) == 'number' then
        if ped and ped ~= 0 then
            playerArmor = GetPedArmour(ped) or 0
        end
    end
    if not info.max then info.max = cfgMax end
    -- Initialize armor field if missing
    if not info.armor then info.armor = playerArmor end
    -- Initialize durability to current max
    if info.durability == nil then
        info.durability = info.max
    end
    exports['qb-inventory']:SetItemData(src, itemName, 'info', info, slot)
    return info
end

local function GetCarrierDurability(it)
    local d = tonumber(it and it.info and it.info.durability or 0) or 0
    local max = GetCarrierMaxForItem(it)
    if d < 0 then d = 0 end
    if d > max then d = max end
    return d
end

local function SetCarrierDurability(src, slot, itemName, info, newVal)
    info = info or {}
    local max = tonumber(info.max or GetConfigCarrierMax(itemName)) or 0
    local v = tonumber(newVal or 0) or 0
    if v < 0 then v = 0 end
    if max > 0 and v > max then v = max end
    info.durability = v
    exports['qb-inventory']:SetItemData(src, itemName, 'info', info, slot)
    return v, max
end

local function SetCarrierArmor(src, slot, itemName, info, newVal)
    info = info or {}
    local maxCap = GetConfigCarrierArmor(itemName or (info and info.name))
    local v = tonumber(newVal or 0) or 0
    if v < 0 then v = 0 end
    if maxCap > 0 and v > maxCap then v = maxCap end
    info.armor = v
    -- Only write back when we know what we're updating
    if slot and itemName then
        exports['qb-inventory']:SetItemData(src, itemName, 'info', info, slot)
    end
    return v, maxCap
end

-- Apply a new max cap to the carrier (and clamp durability if needed)
local function SetCarrierMax(src, slot, itemName, info, newMax)
    info = info or {}
    local max0 = tonumber(info.max0 or GetConfigCarrierMax(itemName)) or 0
    local nm = math.max(0, math.floor(tonumber(newMax or 0) or 0))
    -- never exceed factory max0; never be negative
    if max0 > 0 and nm > max0 then nm = max0 end
    info.max = nm
    -- Clamp durability down if above new cap
    local d = tonumber(info.durability or 0) or 0
    if d > nm then info.durability = nm end
    exports['qb-inventory']:SetItemData(src, itemName, 'info', info, slot)
    return info.max, info.durability or 0, max0
end

local function IsGateOpen(src, Player)
    if Config.RequireNotSwimming then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and IsPedSwimming(ped) then
            return false
        end
    end
    if Player and Player.PlayerData and Player.PlayerData.metadata then
        local md = Player.PlayerData.metadata
        if Config.RequireNotDowned and (md.inlaststand or md.isdead) then
            return false
        end
        if Config.RequireNotCuffed and (md.ishandcuffed or md.isHandcuffed) then
            return false
        end
    end
    return true
end

local function HasEquippedOfType(src, typeName)
    local eq = equippedCarrier[src]
    return eq and eq.type == typeName and eq.carrierId
end

---------------------------------------
-- Plate throughput helpers
---------------------------------------
local function pruneWindow(list, cutoff)
    local out = {}
    for _, t in ipairs(list or {}) do
        if t >= cutoff then table.insert(out, t) end
    end
    return out
end

local function checkAndMarkPlateLimit(src, plateName, plateDef)
    plateRollWindow[src] = plateRollWindow[src] or {}
    lastPlateUseByItem[src] = lastPlateUseByItem[src] or {}

    -- Global floor (applies before item cooldown)
    local gFloor = Config.PlateCooldownMs or 0
    if gFloor > 0 and lastPlateUseAny[src] and (nowMs() - lastPlateUseAny[src] < gFloor) then
        return false, ('You must wait %dms before using another plate.'):format(gFloor)
    end

    -- Per-plate cooldown
    local cd = tonumber(plateDef and plateDef.cooldownMs or 0) or 0
    if cd > 0 then
        local last = lastPlateUseByItem[src][plateName]
        if last and (nowMs() - last < cd) then
            local wait = cd - (nowMs() - last)
            return false, ('You must wait %dms before using %s again.'):format(wait, plateName)
        end
    end

    -- Rolling window limit
    local lim = plateDef and plateDef.limit
    if lim and lim.windowMs and lim.maxUses then
        local wMs  = tonumber(lim.windowMs) or 0
        local maxU = tonumber(lim.maxUses) or 0
        if wMs > 0 and maxU > 0 then
            local arr  = plateRollWindow[src][plateName] or {}
            local cut  = nowMs() - wMs
            arr = pruneWindow(arr, cut)
            if #arr >= maxU then
                return false, ('You can only use %s %d time(s) every %ds.'):format(plateName, maxU, math.floor(wMs/1000))
            end
            table.insert(arr, nowMs())
            plateRollWindow[src][plateName] = arr
        end
    end

    lastPlateUseAny[src] = nowMs()
    lastPlateUseByItem[src][plateName] = nowMs()
    return true
end

local function rollbackPlateLimitTick(src, plateName, plateDef)
    if not plateDef or not plateDef.limit then return end
    local arr = plateRollWindow[src] and plateRollWindow[src][plateName]
    if not arr or #arr == 0 then return end
    table.remove(arr, #arr)
end

---------------------------------------
-- Useable carriers: toggle equip on client (auto-register from Config)
---------------------------------------
for carrierName, data in pairs(Config.PlateCarriers or {}) do
    QBCore.Functions.CreateUseableItem(carrierName, function(src, item)
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end

        if item and item.slot then
            local info = EnsureCarrierInfo(src, item.slot, item.name, item.info or {})
            if (tonumber(info.durability or 0) or 0) <= 0 then
                Notify(src, 'This carrier is destroyed and can no longer be equipped.', 'error')
                return
            end
        end

        TriggerClientEvent('gravvy_kevlar:client:useVest', src, item)
    end)
end

---------------------------------------
-- Plate usage (auto-register from Config.Plates)
---------------------------------------
local function UsePlate(src, plateName, plateDef, usedItem)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if usingPlate[src] then return end
    usingPlate[src] = true
    local function finish() usingPlate[src] = nil end

    if not IsGateOpen(src, Player) then finish(); return end

    -- Check if the player's armor is already at 100 or not
    local ped = GetPlayerPed(src)
    local curArmor = (ped and ped ~= 0) and (GetPedArmour(ped) or 0) or 0
    local maxArmor = Config.Defaults.ArmorMaximum or 100

    if curArmor >= maxArmor then
        Notify(src, 'Your armor is already full.', 'error')
        finish(); return
    end

    if Config.RequireEquippedToPlate then
        local needsType = plateDef and plateDef.type
        if not needsType or not HasEquippedOfType(src, needsType) then
            Notify(src, 'You need to equip a matching plate carrier first.', 'error')
            finish(); return
        end
    end

    local ok, reason = checkAndMarkPlateLimit(src, plateName, plateDef)
    if not ok then
        Notify(src, reason or 'You can’t use that plate yet.', 'error')
        finish(); return
    end

    local eq = equippedCarrier[src]
    if not eq or not eq.carrierId then rollbackPlateLimitTick(src, plateName, plateDef); finish(); return end
    local carrierSlot, carrierItem = FindCarrierById(Player, eq.carrierId)
    if not carrierSlot or not carrierItem then rollbackPlateLimitTick(src, plateName, plateDef); finish(); return end

    local carrierCfg = Config.PlateCarriers[carrierItem.name]
    if not carrierCfg or (plateDef and plateDef.type ~= carrierCfg.plateType) then
        Notify(src, 'This plate does not fit your equipped carrier.', 'error')
        rollbackPlateLimitTick(src, plateName, plateDef); finish(); return
    end

    local info = EnsureCarrierInfo(src, carrierSlot, carrierItem.name, carrierItem.info or {})
    local curDur = GetCarrierDurability(carrierItem)
    if curDur <= 0 then
        Notify(src, 'Your carrier is destroyed and cannot accept plates.', 'error')
        rollbackPlateLimitTick(src, plateName, plateDef); finish(); return
    end

    -- optional client progress
    local proceed = true
    if GetResourceState('ox_lib') == 'started' then
        local success, result = pcall(function()
            return lib.callback.await('gravvy_kevlar:plateProgress', src, plateName)
        end)
        proceed = success and (result ~= false)
    end
    if not proceed then
        rollbackPlateLimitTick(src, plateName, plateDef); finish(); return
    end

    -- armor cap check & consume plate
    local ped = GetPlayerPed(src)
    local curArmor = (ped and ped ~= 0) and (GetPedArmour(ped) or 0) or 0
    if curArmor >= Config.Defaults.ArmorMaximum then
        rollbackPlateLimitTick(src, plateName, plateDef); finish(); return
    end

    if not Player.Functions.RemoveItem(plateName, 1, usedItem and usedItem.slot or nil) then
        rollbackPlateLimitTick(src, plateName, plateDef); finish(); return
    end
    if QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[plateName] then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[plateName], 'remove', 1)
    end

    local add = tonumber(plateDef and plateDef.armor or 0) or 0
    local newArmor = math.min(Config.Defaults.ArmorMaximum, curArmor + add)
    Notify(src, 'Plate inserted.', 'success', 2500)
    SetCarrierArmor(src, carrierSlot, carrierItem.name, info, newArmor)
    TriggerClientEvent('gravvy_kevlar:setArmor', src, newArmor)

    finish()
end

for plateName, def in pairs(Config.Plates or {}) do
    QBCore.Functions.CreateUseableItem(plateName, function(src, item)
        UsePlate(src, plateName, def, item)
    end)
end

---------------------------------------
-- Damage - durability scaling
---------------------------------------
local function clamp(val, minv, maxv)
    if minv and val < minv then val = minv end
    if maxv and maxv ~= nil and maxv > 0 and val > maxv then val = maxv end
    return val
end

local function round(n) return math.floor(n + 0.5) end

local function computeDurabilityLoss(carrierItemName, baseDamage, weaponClass, hitZone, isHeadshot)
    local DM = Config.DamageModel or {}
    local loss = tonumber(baseDamage or 0) or 0
    if loss <= 0 then return 0 end

    local gs = tonumber(DM.globalScale or 1.0) or 1.0
    loss = loss * gs

    local wTable = DM.weaponClassScale or {}
    local wScale = tonumber(wTable[weaponClass or 'OTHER'] or wTable.OTHER or 1.0) or 1.0
    loss = loss * wScale

    local hTable = DM.hitZoneScale or {}
    local hScale = tonumber(hTable[hitZone or 'UPPER'] or 1.0) or 1.0
    loss = loss * hScale

    if isHeadshot then
        local hsx = tonumber(DM.headshotExtra or 0) or 0
        loss = loss * (1.0 + hsx)
    end

    local carrierCfg = Config.PlateCarriers[carrierItemName]
    if carrierCfg then
        if isHeadshot and carrierCfg.headshotExtra then
            loss = loss * (1.0 + (tonumber(carrierCfg.headshotExtra) or 0))
        end
        if carrierCfg.resist and weaponClass and carrierCfg.resist[weaponClass] then
            loss = loss * (tonumber(carrierCfg.resist[weaponClass]) or 1.0)
        end
    end

    local clampCfg = DM.clampPerHit or {}
    loss = clamp(loss, clampCfg.min, clampCfg.max)

    loss = round(loss)
    local minFinal = tonumber(DM.minFinalLoss or 1) or 1
    if loss > 0 and loss < minFinal then loss = minFinal end
    if loss < 0 then loss = 0 end
    return loss
end

RegisterNetEvent('gravvy_kevlar:damageCarrier', function(carrierId, dmg)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not carrierId then return end
    local dmgAmt = math.max(0, tonumber(dmg or 0) or 0)
    if dmgAmt <= 0 then return end

    local slot, it = FindCarrierById(Player, carrierId)
    if not slot or not it then return end

    local info = EnsureCarrierInfo(src, slot, it.name, it.info or {})
    local cur  = GetCarrierDurability(it)

    local loss = computeDurabilityLoss(it.name, dmgAmt, 'OTHER', 'UPPER', false)
    local new  = SetCarrierDurability(src, slot, it.name, info, cur - loss)

    if new <= 0 then
        TriggerClientEvent('gravvy_kevlar:forceUnequip', src, 'Carrier destroyed')
        Notify(src, 'Your carrier is destroyed and can no longer be equipped.', 'error')
    end
end)

RegisterNetEvent('gravvy_kevlar:damageCarrierDetailed', function(carrierId, baseDamage, weaponClass, hitZone, isHeadshot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not carrierId then return end

    local dmgAmt = math.max(0, tonumber(baseDamage or 0) or 0)
    if dmgAmt <= 0 then return end

    local slot, it = FindCarrierById(Player, carrierId)
    if not slot or not it then return end

    local info = EnsureCarrierInfo(src, slot, it.name, it.info or {})
    local cur  = GetCarrierDurability(it)

    local loss = computeDurabilityLoss(it.name, dmgAmt, tostring(weaponClass), tostring(hitZone), isHeadshot and true or false)
    local new  = SetCarrierDurability(src, slot, it.name, info, cur - loss)
    local newArmor = SetCarrierArmor(src, slot, it.name, info, (info.armor or 0) - dmgAmt)

    if new <= 0 then
        TriggerClientEvent('gravvy_kevlar:forceUnequip', src, 'Carrier destroyed')
        Notify(src, 'Your carrier is destroyed and can no longer be equipped.', 'error')
    end
end)

---------------------------------------
-- Repair: item-based with partial stack consumption
-- + Diminishing max durability after repair (config)
---------------------------------------

-- Config helpers (with sensible defaults if not present in config.lua)
local function getRepairDiminish()
    local R = (Config and Config.RepairDiminish) or {}
    return {
        enabled        = (R.enabled ~= false),  -- default true
        mode           = (R.mode == 'flat') and 'flat' or 'percent',
        percent        = tonumber(R.percent or 0.05) or 0.05, -- 5% per repair (action or item)
        flat           = math.floor(tonumber(R.flat or 0) or 0),
        minFloorPct    = tonumber(R.minMaxFloorPercent or 0.4) or 0.4, -- never go below 40% of factory max
        applyPerItem   = (R.applyPerItem == true), -- false = one diminish per repair action
        perUseCap      = R.perUseCap and math.max(0, math.floor(tonumber(R.perUseCap) or 0)) or nil,
    }
end

-- Choose which carrier to repair
local function FindDamagedCarrier(Player, appliesTo, preferEquipped, equippedInfo)
    local items = GetPlayerItems(Player)
    local function accept(itemName)
        local cfg = Config.PlateCarriers[itemName]
        if not cfg then return false end
        if appliesTo == 'any' then return true end
        return (cfg.plateType == appliesTo)
    end
    -- Prefer equipped
    if preferEquipped and equippedInfo and equippedInfo.carrierId then
        local eslot, eitem = FindCarrierById(Player, equippedInfo.carrierId)
        if eslot and eitem and accept(eitem.name) then
            local cur = GetCarrierDurability(eitem)
            local max = GetCarrierMaxForItem(eitem)
            if cur < max then
                return eslot, eitem
            end
        end
    end
    -- First damaged match
    for slot, it in pairs(items) do
        if it and Config.PlateCarriers[it.name] and accept(it.name) then
            local cur = GetCarrierDurability(it)
            local max = GetCarrierMaxForItem(it)
            if cur < max then
                return slot, it
            end
        end
    end
    return nil
end

-- Throttles for repair items
local function checkAndMarkRepairLimit(src, itemName, itemDef)
    repairRollWindow[src]    = repairRollWindow[src]    or {}
    lastRepairUseByItem[src] = lastRepairUseByItem[src] or {}

    local cd = tonumber(itemDef and itemDef.cooldownMs or 0) or 0
    if cd > 0 then
        local last = lastRepairUseByItem[src][itemName]
        if last and (nowMs() - last < cd) then
            local wait = cd - (nowMs() - last)
            return false, ('You must wait %dms before using %s again.'):format(wait, itemName)
        end
    end

    local lim = itemDef and itemDef.limit
    if lim and lim.windowMs and lim.maxUses then
        local wMs  = tonumber(lim.windowMs) or 0
        local maxU = tonumber(lim.maxUses) or 0
        if wMs > 0 and maxU > 0 then
            local arr  = repairRollWindow[src][itemName] or {}
            local cut  = nowMs() - wMs
            arr = pruneWindow(arr, cut)
            if #arr >= maxU then
                return false, ('You can only use %s %d time(s) every %ds.'):format(itemName, maxU, math.floor(wMs/1000))
            end
            table.insert(arr, nowMs())
            repairRollWindow[src][itemName] = arr
        end
    end

    lastRepairUseByItem[src][itemName] = nowMs()
    return true
end

local function rollbackRepairTick(src, itemName, itemDef)
    if not itemDef or not itemDef.limit then return end
    local arr = repairRollWindow[src] and repairRollWindow[src][itemName]
    if not arr or #arr == 0 then return end
    table.remove(arr, #arr)
end

-- Core repair logic (stack-aware)
local function UseRepairItem(src, repairItemName, repairDef, usedItem)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not IsGateOpen(src, Player) then return end

    local ok, reason = checkAndMarkRepairLimit(src, repairItemName, repairDef)
    if not ok then Notify(src, reason or 'You can’t repair yet.', 'error'); return end

    local appliesTo = repairDef.appliesTo or 'any'
    local eq        = equippedCarrier[src]
    local carrierSlot, carrierItem

    if Config.AllowRepairEquippedOnly then
        if not eq or not eq.carrierId then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'You must equip a carrier to repair it.', 'error') end
        carrierSlot, carrierItem = FindCarrierById(Player, eq.carrierId)
    else
        carrierSlot, carrierItem = FindDamagedCarrier(Player, appliesTo, Config.RepairPreferEquipped, eq)
    end
    if not carrierSlot or not carrierItem then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'No damaged carrier found to repair.', 'error') end

    local info     = EnsureCarrierInfo(src, carrierSlot, carrierItem.name, carrierItem.info or {})
    local cur      = GetCarrierDurability(carrierItem)
    local maxCap   = GetCarrierMaxForItem(carrierItem)
    if cur >= maxCap then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'That carrier is already at full durability.', 'error') end

    -- How many units are needed from this stack?
    local perUnit  = math.max(0, tonumber(repairDef.value or 0) or 0)
    if perUnit <= 0 then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'Repair item has no effect (value=0).', 'error') end

    -- Figure out how many to consume from THIS stack only (partial consumption)
    local slotToUse = usedItem and usedItem.slot
    local stackItem = nil
    if slotToUse then
        local items = GetPlayerItems(Player)
        stackItem = items[slotToUse]
    end
    if not stackItem or stackItem.name ~= repairItemName then
        -- fallback: first stack
        local fslot, fitem = FindFirst(Player, repairItemName)
        slotToUse, stackItem = fslot, fitem
    end
    if not stackItem then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'No repair materials found.', 'error') end

    local neededDur = maxCap - cur
    local neededUnits = math.ceil(neededDur / perUnit)
    local haveUnits = tonumber(stackItem.amount or stackItem.count or 1) or 1
    if haveUnits <= 0 then rollbackRepairTick(src, repairItemName, repairDef); return Notify(src, 'No repair materials in that stack.', 'error') end

    local consume = math.min(neededUnits, haveUnits)
    local restore = math.min(neededDur, consume * perUnit)

    -- Client progress
    local proceed = true
    if GetResourceState('ox_lib') == 'started' then
        local success, result = pcall(function()
            return lib.callback.await('gravvy_kevlar:repairProgress', src, repairItemName)
        end)
        proceed = success and (result ~= false)
    end
    if not proceed then rollbackRepairTick(src, repairItemName, repairDef); return end

    -- Remove only what we need from this stack
    if not Player.Functions.RemoveItem(repairItemName, consume, slotToUse) then
        rollbackRepairTick(src, repairItemName, repairDef); return
    end
    if QBCore.Shared and QBCore.Shared.Items and QBCore.Shared.Items[repairItemName] then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[repairItemName], 'remove', consume)
    end

    -- Apply the repair
    local newDur, _ = SetCarrierDurability(src, carrierSlot, carrierItem.name, info, cur + restore)

    -- Diminishing max after repair
    local D = getRepairDiminish()
    if D.enabled then
        local max0  = tonumber(info.max0 or GetConfigCarrierMax(carrierItem.name)) or 0
        local curMx = tonumber(info.max or GetConfigCarrierMax(carrierItem.name)) or 0

        -- how many times to apply diminish? perAction (1) or perItem (consume)
        local times = D.applyPerItem and consume or 1

        local diminished = curMx
        for i = 1, times do
            local drop = 0
            if D.mode == 'flat' then
                drop = D.flat
            else
                drop = math.floor(diminished * (D.percent or 0.05))
            end
            if D.perUseCap and drop > D.perUseCap then drop = D.perUseCap end
            if drop <= 0 then break end
            diminished = math.max(0, diminished - drop)
        end

        -- Do not go below floor% of factory max
        if max0 > 0 then
            local floorVal = math.floor(max0 * (D.minFloorPct or 0.4))
            if diminished < floorVal then diminished = floorVal end
            if diminished > max0 then diminished = max0 end
        end

        local newMax, afterClampDur = SetCarrierMax(src, carrierSlot, carrierItem.name, info, diminished)
        newDur = afterClampDur
    end

    Notify(src, ('Carrier repaired: %d → %d / %d'):format(cur, newDur, tonumber(info.max or GetCarrierMaxForItem(carrierItem)) or 0), 'success', 3200)
end

-- Auto-register all repair items from Config
for repName, repDef in pairs(Config.RepairItems or {}) do
    QBCore.Functions.CreateUseableItem(repName, function(src, item)
        UseRepairItem(src, repName, repDef, item)
    end)
end

---------------------------------------
-- Exports: let other resources repair carriers in code
---------------------------------------
local function RepairCarrierById(src, carrierId, amount, opts)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not carrierId then return false end
    local slot, it = FindCarrierById(Player, carrierId)
    if not slot or not it then return false end

    local info = EnsureCarrierInfo(src, slot, it.name, it.info or {})
    local cur  = GetCarrierDurability(it)
    local max  = GetCarrierMaxForItem(it)
    local add  = math.max(0, tonumber(amount or 0) or 0)
    if add <= 0 then return false end

    local newDur, _ = SetCarrierDurability(src, slot, it.name, info, math.min(max, cur + add))

    -- optional diminishing via export (respect config)
    local D = getRepairDiminish()
    if D.enabled and not (opts and opts.skipDiminish) then
        local times = (opts and opts.applyTimes) or 1
        local diminished = tonumber(info.max or GetCarrierMaxForItem(it)) or max
        local max0 = tonumber(info.max0 or GetConfigCarrierMax(it.name)) or max
        for i = 1, times do
            local drop = (D.mode == 'flat') and D.flat or math.floor(diminished * (D.percent or 0.05))
            if D.perUseCap and drop > D.perUseCap then drop = D.perUseCap end
            if drop <= 0 then break end
            diminished = math.max(0, diminished - drop)
        end
        if max0 > 0 then
            local floorVal = math.floor(max0 * (D.minFloorPct or 0.4))
            if diminished < floorVal then diminished = floorVal end
            if diminished > max0 then diminished = max0 end
        end
        local newMax = SetCarrierMax(src, slot, it.name, info, diminished)
        -- durability potentially clamped inside SetCarrierMax
        newDur = tonumber(info.durability or newDur) or newDur
    end

    return true, newDur, tonumber(info.max or GetCarrierMaxForItem(it)) or max
end
exports('RepairCarrierById', RepairCarrierById)

local function RepairEquipped(src, amount, opts)
    local eq = equippedCarrier[src]
    if not eq or not eq.carrierId then return false end
    return RepairCarrierById(src, eq.carrierId, amount, opts)
end
exports('RepairEquipped', RepairEquipped)

local function RepairFirstDamaged(src, appliesTo, amount, opts)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local slot, it = (function()
        return (function()
            local items = GetPlayerItems(Player)
            for s, item in pairs(items) do
                if item and Config.PlateCarriers[item.name] then
                    local c = Config.PlateCarriers[item.name]
                    if appliesTo == 'any' or c.plateType == appliesTo then
                        local cur = GetCarrierDurability(item)
                        local max = GetCarrierMaxForItem(item)
                        if cur < max then return s, item end
                    end
                end
            end
            return nil
        end)()
    end)()
    if not slot or not it then return false end

    local info = EnsureCarrierInfo(src, slot, it.name, it.info or {})
    local cur  = GetCarrierDurability(it)
    local max  = GetCarrierMaxForItem(it)
    local add  = math.max(0, tonumber(amount or 0) or 0)
    if add <= 0 then return false end

    local newDur, _ = SetCarrierDurability(src, slot, it.name, info, math.min(max, cur + add))

    -- diminishing (same rules)
    local D = getRepairDiminish()
    if D.enabled and not (opts and opts.skipDiminish) then
        local times = (opts and opts.applyTimes) or 1
        local diminished = tonumber(info.max or GetCarrierMaxForItem(it)) or max
        local max0 = tonumber(info.max0 or GetConfigCarrierMax(it.name)) or max
        for i = 1, times do
            local drop = (D.mode == 'flat') and D.flat or math.floor(diminished * (D.percent or 0.05))
            if D.perUseCap and drop > D.perUseCap then drop = D.perUseCap end
            if drop <= 0 then break end
            diminished = math.max(0, diminished - drop)
        end
        if max0 > 0 then
            local floorVal = math.floor(max0 * (D.minFloorPct or 0.4))
            if diminished < floorVal then diminished = floorVal end
            if diminished > max0 then diminished = max0 end
        end
        local newMax = SetCarrierMax(src, slot, it.name, info, diminished)
        newDur = tonumber(info.durability or newDur) or newDur
    end

    return true, newDur, tonumber(info.max or GetCarrierMaxForItem(it)) or max
end
exports('RepairFirstDamaged', RepairFirstDamaged)

---------------------------------------
-- Track equipped carrier state from client
---------------------------------------
RegisterNetEvent('gravvy_kevlar:server:setEquipped', function(carrierId, typeName)
    local src = source
    if carrierId and typeName then
        equippedCarrier[src] = { carrierId = carrierId, type = typeName }
    else
        equippedCarrier[src] = nil
    end
end)

-- Cleanup on disconnect
AddEventHandler('playerDropped', function()
    local src = source
    lastPlateUseAny[src]     = nil
    usingPlate[src]          = nil
    equippedCarrier[src]     = nil
    lastPlateUseByItem[src]  = nil
    plateRollWindow[src]     = nil
    lastRepairUseByItem[src] = nil
    repairRollWindow[src]    = nil
end)

-- Vest registration (returns durability + type)
lib.callback.register('gravvy_kevlar:registerCarrier', function(src, slot)
    if not slot then return end
    local clicked = exports['qb-inventory']:GetItemBySlot(src, slot)
    if not clicked or not Config.PlateCarriers[clicked.name] then return end
    local info = EnsureCarrierInfo(src, slot, clicked.name, clicked.info or {})
    local dur  = tonumber(info.durability or info.max or GetConfigCarrierMax(clicked.name)) or GetConfigCarrierMax(clicked.name)
    local armor = tonumber(info.armor or GetConfigCarrierArmor(clicked.name)) or GetConfigCarrierArmor(clicked.name)
    return {
        carrierId  = info.carrierId,
        plate_type = Config.PlateCarriers[clicked.name].plateType,
        durability = dur,
        armor      = armor
    }
end)

-- Server-side environment gate for plate use (kept for parity)
lib.callback.register('gravvy_kevlar:allowApplyStored', function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return IsGateOpen(src, Player)
end)
