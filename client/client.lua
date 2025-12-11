--[[
    Pet System - Wild West Edition
    Client Script
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Helper function for notifications
local function Notify(message, type)
    lib.notify({
        title = 'Pets',
        description = message,
        type = type or 'inform',
        duration = 5000
    })
end

-- State
local petOut = false
local currentPet = nil
local shopNPCs = {}


Citizen.CreateThread(function()
    -- Create shop blips and NPCs
    for _, shop in pairs(Config.PetShopLocations) do
        -- Create blip if enabled
        if shop.showblip and Config.EnableBlip then
            local blip = N_0x554d9d53f696d002(1664425300, shop.coords)
            SetBlipSprite(blip, Config.Blip.blipSprite, 1)
            SetBlipScale(blip, Config.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.Blip.blipName)
        end
        
        -- Spawn shop NPC
        SpawnShopNPC(shop)
    end
end)



function SpawnShopNPC(shop)
    local model = GetHashKey(shop.npcModel)
    
    -- if Config.Debug then print('[Pet System] Spawning shop NPC at: ' .. shop.coords) end
    
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 100 then
            print('[Pet System] Failed to load NPC model: ' .. shop.npcModel)
            return
        end
    end
    
    -- Request collision and find ground Z
    RequestCollisionAtCoord(shop.coords.x, shop.coords.y, shop.coords.z)
    local groundZ = shop.coords.z
    local hasGround = false
    local attempts = 0
    
    while not hasGround and attempts < 20 do
        Wait(100)
        local found, z = GetGroundZFor_3dCoord(shop.coords.x, shop.coords.y, shop.coords.z + 50.0, false)
        if found then
            groundZ = z
            hasGround = true
        end
        attempts = attempts + 1
    end
    
    -- If ground found, spawn slightly above and snap
    local spawnZ = hasGround and groundZ or shop.coords.z
    local npc = CreatePed(model, shop.coords.x, shop.coords.y, spawnZ, shop.heading, false, false, false, false)
    
    Citizen.InvokeNative(0x283978A15512B2FE, npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    PlaceObjectOnGroundProperly(npc)
    FreezeEntityPosition(npc, true)
    
    -- Add third-eye interaction to NPC
    exports['rsg-target']:AddTargetEntity(npc, {
        options = {
            {
                type = "client",
                event = "rsg-pets:client:openShop",
                icon = "fas fa-paw",
                label = "Open Pet Shop",
                shopName = shop.name
            }
        },
        distance = 3.0
    })
    
    table.insert(shopNPCs, npc)
    
    SetModelAsNoLongerNeeded(model)
end

-- Cleanup NPCs on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for _, npc in pairs(shopNPCs) do
        if DoesEntityExist(npc) then
            DeleteEntity(npc)
        end
    end
end)



-- Close shop NUI
RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Close pet status NUI
RegisterNUICallback('closeStatus', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Close feed menu NUI
RegisterNUICallback('closeFeedMenu', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Select food from feed menu
RegisterNUICallback('selectFood', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
    
    -- Trigger feed event with selected food
    TriggerEvent('rsg-pets:client:feedPet', data.itemName, data.itemLabel)
end)

-- Purchase pet
RegisterNUICallback('purchasePet', function(data, cb)
    TriggerServerEvent('rsg-pets:server:purchasePet', data.petName, data.price)
    cb('ok')
end)



-- Open pet shop (NUI version)
RegisterNetEvent('rsg-pets:client:openShop')
AddEventHandler('rsg-pets:client:openShop', function(data)
    -- Get player money
    local Player = RSGCore.Functions.GetPlayerData()
    local money = Player.money.cash or 0
    
    -- Convert pets config to array for NUI
    local petsArray = {}
    for petName, petData in pairs(Config.Pets) do
        table.insert(petsArray, {
            name = petData.name,
            label = petData.label,
            type = petData.type,
            price = petData.price,
            description = petData.description,
            image = petData.image
        })
    end
    
    -- Sort by type then price
    table.sort(petsArray, function(a, b)
        if a.type == b.type then
            return a.price < b.price
        end
        return a.type < b.type
    end)
    
    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openShop',
        pets = petsArray,
        money = money
    })
end)

-- Update money display
RegisterNetEvent('rsg-pets:client:updateMoney')
AddEventHandler('rsg-pets:client:updateMoney', function(money)
    SendNUIMessage({
        action = 'updateMoney',
        money = money
    })
end)

-- Purchase result
RegisterNetEvent('rsg-pets:client:purchaseResult')
AddEventHandler('rsg-pets:client:purchaseResult', function(success, message)
    if success then
        Notify(message, 'success')
    else
        Notify(message, 'error')
    end
    
    SendNUIMessage({
        action = 'purchaseResult',
        success = success,
        message = message
    })
end)



-- Universal pet call event
RegisterNetEvent('rsg-pets:client:callPet')
AddEventHandler('rsg-pets:client:callPet', function(petName, itemInfo)
    local petConfig = Config.Pets[petName]
    
    if not petConfig then
        Notify(_L('no_pet'), 'error')
        return
    end
    
    -- Check for persisted name in item metadata
    local displayName = petConfig.label
    if itemInfo and itemInfo.petName then
        displayName = itemInfo.petName
    end
    
    -- Server already validated item ownership when CreateUseableItem callback triggered
    
    if petOut then
        -- Dismiss current pet
        if currentPet and currentPet.delete then
            currentPet.delete()
        end
        petOut = false
        currentPet = nil
        Notify(_L('pet_dismissed'), 'success')
    else
        -- Spawn new pet
        if petConfig.type == 'dog' then
            currentPet = newDoggo(petConfig.model, displayName, petName) -- Pass petName (item name) for persistence
        elseif petConfig.type == 'cat' then
            currentPet = newCat(petConfig.model, displayName, petName) -- Pass petName (item name) for persistence
        end
        
        petOut = true
        
        if currentPet and currentPet.whistle then
            currentPet.whistle()
        end
        
        Wait(Config.WhistleWait)
        Notify(string.format(_L('pet_called'), petConfig.label), 'success')
    end
end)



local function createLegacyHandler(petName)
    RegisterNetEvent('rsg-pets:client:call' .. petName)
    AddEventHandler('rsg-pets:client:call' .. petName, function()
        TriggerEvent('rsg-pets:client:callPet', petName)
    end)
end

-- Register legacy handlers for all dogs
createLegacyHandler('foxhound')
createLegacyHandler('sheperd')
createLegacyHandler('coonhound')
createLegacyHandler('catahoulacur')
createLegacyHandler('bayretriever')
createLegacyHandler('collie')
createLegacyHandler('hound')
createLegacyHandler('husky')
createLegacyHandler('lab')
createLegacyHandler('poodle')
createLegacyHandler('street')
createLegacyHandler('tabbycat')



-- Whistle for pet
RegisterCommand('petwhistle', function()
    if currentPet and currentPet.whistle then
        currentPet.whistle()
    else
        Notify('No pet is currently with you!', 'error')
    end
end, false)

-- Dismiss pet
RegisterCommand('petdismiss', function()
    if currentPet then
        currentPet.delete()
        petOut = false
        currentPet = nil
        Notify(_L('pet_dismissed'), 'success')
    end
end, false)


RegisterNetEvent('rsg-pets:client:feedPet')
AddEventHandler('rsg-pets:client:feedPet', function(itemName, itemLabel)
    if not currentPet then 
        Notify('No pet to feed!', 'error')
        return
    end
    
    local foodData = Config.PetFood[itemName]
    if not foodData then return end
    
    -- Freeze player and play animation
    local player = PlayerPedId()
    FreezeEntityPosition(player, true)
    
    -- Request and play crouch animation
    local animDict = 'script_common@shared_scenarios@pairedbase'
    RequestAnimDict(animDict)
    local timeout = 0
    while not HasAnimDictLoaded(animDict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    TaskPlayAnim(player, animDict, 'petting_animal', 8.0, -8.0, 5000, 1, 0, false, false, false)
    
    -- Show custom progress bar
    local finished = false
    local cancelled = false
    
    -- Function to handle NUI completion
    local progressBarHandler
    local cancelParams = {
        car = true,
        move = true,
        combat = true
    }
    
    -- Disable controls
    CreateThread(function()
        while not finished and not cancelled do
            Wait(0)
            DisableAllControlActions(0)
            if IsDisabledControlJustPressed(0, 200) then -- ESC or Right Mouse
                cancelled = true
                -- Send cancel to NUI
                SendNUIMessage({ action = 'cancelProgressBar' })
            end
        end
    end)
    
    -- Show NUI
    SetNuiFocus(false, false) -- Keep focus false to allow movement/interaction denial via Lua
    SendNUIMessage({
        action = 'showProgressBar',
        duration = 5000,
        label = 'Feeding ' .. currentPet.name .. '...'
    })
    
    -- Wait for completion or cancel
    local timer = 0
    while not finished and not cancelled and timer < 5500 do
        Wait(100)
        timer = timer + 100
        if timer >= 5000 then finished = true end
    end
    
    if finished and not cancelled then
        -- Success - update pet stats
        currentPet.hunger = math.min(100, (currentPet.hunger or 100) + foodData.hunger)
        currentPet.health = math.min(100, (currentPet.health or 100) + foodData.health)
        
        -- Remove item from inventory
        TriggerServerEvent('rsg-pets:server:feedPet', itemName)
        Notify(currentPet.name .. ' enjoyed the ' .. itemLabel .. '!', 'success')
    else
        Notify('Feeding cancelled', 'error')
    end
    
    -- Unfreeze player and clear animation
    ClearPedTasks(player)
    FreezeEntityPosition(player, false)
end)


function newCat(model, name, petItemName) -- Added petItemName parameter
    local object = {}
    object.petItemName = petItemName -- Store item name for persistence
    object.spawned = false
    object.model = model
    object.pos = false
    object.id = false
    object.name = name
    object.state = false
    object.followingRange = Config.PetBehavior.followingRange
    object.wanderingRange = Config.PetBehavior.wanderingRange
    object.playerRange = Config.PetBehavior.playerRange
    
    -- Pet Stats
    object.health = 100
    object.hunger = 100
    object.birthTime = GetGameTimer() -- When pet was spawned (in milliseconds)

    -- Spawn cat
    Citizen.CreateThread(function()
        while not object.spawned do
            Wait(100)
            -- if Config.Debug then print('[Pet System] Loading pet: ' .. object.model) end
            
            local catModel = GetHashKey(object.model)
            RequestModel(catModel)
            while not HasModelLoaded(catModel) do
                Wait(500)
            end
            
            local player = PlayerPedId()
            local offset = GetOffsetFromEntityInWorldCoords(player, 0.0, 3.0, 0.0)
            local _, groundZ = GetGroundZAndNormalFor_3dCoord(offset.x, offset.y, offset.z + 10)
            
            while not groundZ do
                Wait(100)
                _, groundZ = GetGroundZAndNormalFor_3dCoord(offset.x, offset.y, offset.z + 10)
            end
            
            object.id = CreatePed(catModel, offset.x, offset.y, groundZ, 180.0, true, false)
            
            while not DoesEntityExist(object.id) do
                Wait(300)
            end
            
            Citizen.InvokeNative(0x283978A15512B2FE, object.id, true)
            SetPedAsGroupMember(object.id, GetPedGroupIndex(PlayerPedId()))
            SetPedPromptName(object.id, object.name)
            SetBlockingOfNonTemporaryEvents(object.id, true)
            
            object.pos = GetEntityCoords(object.id)
            object.spawned = true
            
            -- Add blip
            if Config.EnableBlip then
                Citizen.InvokeNative(0x23f74c2fda6e7c61, -1749618580, object.id)
            end
            
            -- Start following
            object.followTask()
            
            -- Wait for entity to fully register
            Wait(500)
            
            -- Add third-eye target interactions
            exports['rsg-target']:AddTargetEntity(object.id, {
                options = {
                    {
                        type = "client",
                        action = function()
                            -- Pet the cat animation
                            local player = PlayerPedId()
                            local animDict = 'script_common@shared_scenarios@pairedbase'
                            RequestAnimDict(animDict)
                            local timeout = 0
                            while not HasAnimDictLoaded(animDict) and timeout < 100 do
                                Wait(10)
                                timeout = timeout + 1
                            end
                            TaskPlayAnim(player, animDict, 'petting_animal', 8.0, -8.0, 3000, 0, 0, false, false, false)
                            lib.notify({ title = 'Pets', description = 'You pet ' .. object.name, type = 'success', duration = 3000 })
                            Wait(3000)
                            ClearPedTasks(player)
                        end,
                        icon = "fas fa-heart",
                        label = "Pet " .. object.name,
                    },
                    {
                        type = "client",
                        action = function()
                            object.state = 'resting'
                            ClearPedTasks(object.id)
                            lib.notify({ title = 'Pets', description = object.name .. ' is now staying', type = 'inform', duration = 3000 })
                        end,
                        icon = "fas fa-hand",
                        label = "Stay",
                    },
                    {
                        type = "client",
                        action = function()
                            object.followTask()
                            lib.notify({ title = 'Pets', description = object.name .. ' is following you', type = 'inform', duration = 3000 })
                        end,
                        icon = "fas fa-person-walking",
                        label = "Follow Me",
                    },
                    {
                        type = "client",
                        action = function()
                            object.state = 'sleeping'
                            ClearPedTasks(object.id)
                            lib.notify({ title = 'Pets', description = object.name .. ' is resting', type = 'inform', duration = 3000 })
                        end,
                        icon = "fas fa-bed",
                        label = "Rest",
                    },
                    {
                        type = "client",
                        action = function()
                            -- Calculate lifespan remaining (convert ms to seconds)
                            local age = (GetGameTimer() - object.birthTime) / 1000
                            local lifespanRemaining = Config.PetLifespan - age
                            local lifespanPercent = (lifespanRemaining / Config.PetLifespan) * 100
                            
                            SetNuiFocus(true, true)
                            SendNUIMessage({
                                action = 'showPetStatus',
                                name = object.name,
                                health = object.health,
                                hunger = object.hunger,
                                lifespan = lifespanPercent,
                                lifespanSeconds = lifespanRemaining
                            })
                        end,
                        icon = "fas fa-chart-line",
                        label = "Check Status",
                    },
                    {
                        type = "client",
                        action = function()
                            -- Get food items from player inventory
                            local PlayerData = RSGCore.Functions.GetPlayerData()
                            local foodItems = {}
                            
                            for itemName, foodData in pairs(Config.PetFood) do
                                for _, item in pairs(PlayerData.items or {}) do
                                    if item and item.name == itemName and item.amount > 0 then
                                        table.insert(foodItems, {
                                            name = itemName,
                                            label = foodData.label,
                                            hunger = foodData.hunger,
                                            health = foodData.health,
                                            amount = item.amount
                                        })
                                        break
                                    end
                                end
                            end
                            
                            -- Open custom feed NUI
                            SetNuiFocus(true, true)
                            SendNUIMessage({
                                action = 'showFeedMenu',
                                petName = object.name,
                                foodItems = foodItems
                            })
                        end,
                        icon = "fas fa-drumstick-bite",
                        label = "Feed",
                    },
                    {
                        type = "client",
                        action = function()
                            local input = lib.inputDialog('Rename Pet', {
                                { type = 'input', label = 'New Name', description = 'Max 12 characters', required = true, min = 1, max = 12 }
                            })
                            
                            if input and input[1] and #input[1] <= 12 then
                                local newName = input[1]
                                object.name = newName
                                SetPedPromptName(object.id, newName)
                                
                                -- Trigger server event to save name if we have the item name
                                if object.petItemName then
                                    TriggerServerEvent('rsg-pets:server:updatePetName', object.petItemName, newName)
                                end
                                
                                lib.notify({ title = 'Pets', description = 'Renamed pet to ' .. newName, type = 'success', duration = 3000 })
                            elseif input and input[1] and #input[1] > 12 then
                                lib.notify({ title = 'Pets', description = 'Name too long! Max 12 characters.', type = 'error', duration = 3000 })
                            end
                        end,
                        icon = "fas fa-pen",
                        label = "Rename",
                    },
                },
                distance = 3.0,
            })
        end
    end)
    
    -- Follow loop
    Citizen.CreateThread(function()
        while true do
            Wait(1000)
            if object.spawned and DoesEntityExist(object.id) then
                local playerPos = GetEntityCoords(PlayerPedId())
                object.pos = GetEntityCoords(object.id)
                local dist = #(playerPos - object.pos)
                
                if dist > object.followingRange * 2 then
                    object.followTask()
                end
            else
                break
            end
        end
    end)

    function object:delete()
        if DoesEntityExist(object.id) then
            SetEntityAsMissionEntity(object.id, true, true)
            DeletePed(object.id)
        end
        object.spawned = false
    end

    function object:whistle()
        Citizen.InvokeNative(0xD6401A1B2F63BED6, PlayerPedId(), 869278708, 1971704925)
        object.state = 'following'
        object.followTask()
    end

    function object:followTask()
        object.state = 'following'
        Citizen.InvokeNative(0x304AE42E357B8C7E, object.id, PlayerPedId(), 0.0, 3.0, 0.0, -1, -1, object.followingRange, true, true, false, true, true)
    end

    function object:getPos()
        return GetEntityCoords(object.id)
    end

    return object
end


AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    -- Delete spawned pet
    if currentPet and currentPet.delete then
        currentPet.delete()
    end
    
    -- Delete shop NPCs
    for _, npc in pairs(shopNPCs) do
        if DoesEntityExist(npc) then
            DeletePed(npc)
        end
    end
end)
