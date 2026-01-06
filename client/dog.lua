--[[
    RSG-Pets Enhanced - Wild West Edition
    Dog Companion Class
    Based on K_DOGGO by kurdt94 (https://github.com/kurdt94/k_doggo)
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

function newDoggo(model, name, petItemName, skin, slot)
    local object = {}
    object.petItemName = petItemName -- Store item name for persistence
    object.skin = skin -- Store default skin
    object.slot = slot -- Store slot
    object.spawned = false
    object.model = model
    object.pos = false
    object.id = false
    object.name = name
    object.state = false
    object.blip = false
    object.isSleeping = false
    object.followingRange = Config.PetBehavior.followingRange
    object.wanderingRange = Config.PetBehavior.wanderingRange
    object.smellingRange = Config.PetBehavior.smellingRange
    object.playerRange = Config.PetBehavior.playerRange
    object.counters = { resting = 0 }
    object.huntingList = {}
    object.foundList = {}
    
    -- Pet Stats
    object.health = 100
    object.hunger = 100
    object.birthTime = GetGameTimer() -- When pet was spawned (in milliseconds)
    
    object.volume = Citizen.InvokeNative(0xB3FB80A32BAE3065, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, object.smellingRange, object.smellingRange, object.smellingRange)
    object.itemset = CreateItemset(1)

    -------------------------------------------------
    -- INITIALIZATION
    -------------------------------------------------
    Citizen.CreateThread(function()
        while not object.spawned do
            Wait(100)
            if Config.Debug then print('[rsg-pets] Loading pet: ' .. object.model) end
            
            local pedModel = GetHashKey(object.model)
            RequestModel(pedModel)
            while not HasModelLoaded(pedModel) do
                Wait(500)
            end
            
            local player = PlayerPedId()
            local offset = GetOffsetFromEntityInWorldCoords(player, 0.0, 5.0, 0.0)
            local _, groundZ = GetGroundZAndNormalFor_3dCoord(offset.x, offset.y, offset.z + 10)
            
            while not groundZ do
                Wait(100)
                _, groundZ = GetGroundZAndNormalFor_3dCoord(offset.x, offset.y, offset.z + 10)
            end
            
            object.id = CreatePed(pedModel, offset.x, offset.y, groundZ, 180.0, true, false)
            
            while not DoesEntityExist(object.id) do
                Wait(300)
            end

            -- Apply Skin/Variation if defined
            if object.skin then
                -- _SET_PED_TEXTURE_VARIATION
                Citizen.InvokeNative(0xA6D8D713, object.id, object.skin)
                -- Also try SetPedOutfitPreset just in case
                Citizen.InvokeNative(0x77F5497E2CE9709E, object.id, object.skin, 0)
            end
            
            Citizen.InvokeNative(0x283978A15512B2FE, object.id, true)
            SetPedAsGroupMember(object.id, GetPedGroupIndex(PlayerPedId()))
            SetPedPromptName(object.id, object.name)
            SetBlockingOfNonTemporaryEvents(object.id, true)
            
            object.pos = GetEntityCoords(object.id)
            object.spawned = true
            
            -- Blip
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
                            -- Pet the dog animation
                            local player = PlayerPedId()
                            local animDict = 'script_common@shared_scenarios@pairedbase'
                            RequestAnimDict(animDict)
                            local timeout = 0
                            while not HasAnimDictLoaded(animDict) and timeout < 100 do
                                Wait(10)
                                timeout = timeout + 1
                            end
                            TaskPlayAnim(player, animDict, 'petting_animal', 8.0, -8.0, 3000, 0, 0, false, false, false)
                            -- Dog sits
                            TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SITTING'), 3000, true, false, false, false)
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
                            TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SITTING'), -1, true, false, false, false)
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
                            TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SLEEPING'), -1, true, false, false, false)
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
                            
                            -- Open status NUI
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
                                    TriggerServerEvent('rsg-pets:server:updatePetName', object.petItemName, newName, object.slot)
                                end
                                
                                lib.notify({ title = 'Pets', description = 'Renamed pet to ' .. newName, type = 'success', duration = 3000 })
                            elseif input and input[1] and #input[1] > 12 then
                                lib.notify({ title = 'Pets', description = 'Name too long! Max 12 characters.', type = 'error', duration = 3000 })
                            end
                        end,
                        icon = "fas fa-pen",
                        label = "Rename",
                    },
                    {
                        type = "client",
                        action = function()
                            TriggerEvent('rsg-pets:client:dismissPet')
                        end,
                        icon = "fas fa-sign-out-alt",
                        label = "Flee",
                    },
                },
                distance = 3.0,
            })
        end
    end)

    -------------------------------------------------
    -- MAIN BEHAVIOR LOOP (200ms tick)
    -------------------------------------------------
    Citizen.CreateThread(function()
        while object.spawned do
            Wait(200)
            
            if not DoesEntityExist(object.id) then break end
            
            local playerpos = GetEntityCoords(PlayerPedId())
            object.pos = GetEntityCoords(object.id)
            local dist = #(playerpos - object.pos)

            Citizen.InvokeNative(0x541B8576615C33DE, object.volume, object.pos.x, object.pos.y, object.pos.z)
            Wait(100)

            local pedsFound = Citizen.InvokeNative(0x886171A12F400B89, object.volume, object.itemset, 1)
            Wait(100)

            if pedsFound then
                local n = 0
                while n < pedsFound do
                    local item = GetIndexedItemInItemset(n, object.itemset)
                    if IsEntityDead(item) and Citizen.InvokeNative(0x93C8B64DEB84728C, item) == PlayerPedId() and not Citizen.InvokeNative(0xB980061DA992779D, item) and object.huntingList[item] ~= 'found' then
                        object.huntingList[item] = item
                        object.state = 'hunting'
                    end
                    n = n + 1
                end
                Citizen.InvokeNative(0x20A4BF0E09BEE146, object.itemset)
            end

            if dist <= object.playerRange and object.state ~= 'hunting' and object.state ~= 'sleeping' and object.state ~= 'resting' and Citizen.InvokeNative(0xAC29253EEF8F0180, player) then
                object.state = 'resting'
                TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SITTING'), -1, true, false, false, false)
            end
        end
    end)

    -------------------------------------------------
    -- STATE MANAGEMENT LOOP (1000ms tick)
    -------------------------------------------------
    Citizen.CreateThread(function()
        while object.spawned do
            Wait(1000)
            
            if not DoesEntityExist(object.id) then break end
            
            local player = PlayerPedId()
            local dCoords = GetEntityCoords(object.id)
            local pCoords = GetEntityCoords(PlayerPedId())
            local dist = #(dCoords - pCoords)

            if Citizen.InvokeNative(0xAC29253EEF8F0180, player) and object.state ~= 'wandering' and object.state ~= 'hunting' and object.state ~= 'resting' and object.state ~= 'sleeping' then
                object.state = 'wandering'
                object.isSleeping = false
                object.wanderTask()
            elseif object.state == 'resting' and Citizen.InvokeNative(0xAC29253EEF8F0180, player) and object.state ~= 'hunting' then
                object.isSleeping = false
                object.restingTask()
            elseif object.state == 'hunting' then
                object.isSleeping = false
                object.huntingTask()
            else
                if not Citizen.InvokeNative(0xAC29253EEF8F0180, player) and object.state ~= 'following' and object.state ~= 'hunting' then
                    object.isSleeping = false
                    object.followTask()
                end
            end
        end
    end)

    -------------------------------------------------
    -- TERRITORY MARKING (random chance)
    -------------------------------------------------
    Citizen.CreateThread(function()
        while object.spawned do
            Wait(1000)
            if object.state == 'wandering' then
                local markChance = math.random(1, 10000)
                if markChance > 9975 then
                    TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_MARK_TERRITORY_A'), 3000, true, false, false, false)
                    Wait(3000)
                    object.wanderTask()
                end
            end
        end
    end)

    -------------------------------------------------
    -- METHODS
    -------------------------------------------------
    
    function object:getVolume()
        return object.volume
    end

    function object:delete()
        if DoesEntityExist(object.id) then
            SetEntityAsMissionEntity(object.id, true, true)
            DeletePed(object.id)
        end
        object.spawned = false
    end

    function object:getPos()
        return GetEntityCoords(object.id)
    end

    function object:whistle()
        Citizen.InvokeNative(0xD6401A1B2F63BED6, PlayerPedId(), 869278708, 1971704925)
        object.state = 'following'
        Citizen.InvokeNative(0x304AE42E357B8C7E, object.id, PlayerPedId(), 0.0, 4.0, 0.0, -1, -1, object.followingRange, true, true, false, true, true)
    end

    function object:getModel()
        return object.model
    end

    function object:setName(newName)
        object.name = newName
        SetPedPromptName(object.id, object.name)
    end

    function object:setState(newState)
        object.state = newState
    end

    function object:followTask()
        object.state = 'following'
        Citizen.InvokeNative(0x304AE42E357B8C7E, object.id, PlayerPedId(), 0.0, 4.0, 0.0, -1, -1, object.followingRange, true, true, false, true, true)
    end

    function object:sleepingTask()
        if not object.isSleeping then
            object.isSleeping = true
            TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SLEEPING'), -1, true, false, false, false)
        end
    end

    function object:wanderTask()
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        Citizen.InvokeNative(0xE054346CA3A0F315, object.id, coords.x, coords.y, coords.z, object.wanderingRange, tonumber(1077936128), tonumber(1086324736), 1)
        Wait(4000)
        object.counters.resting = 0
    end

    function object:restingTask()
        object.counters.resting = object.counters.resting + 1
        
        if object.counters.resting >= 94 then
            if math.random(1, 100) > 40 then
                object.wanderTask()
                Wait(4000)
                object.state = 'wandering'
                return
            else
                object.sleepingTask()
                Wait(4000)
                object.state = 'sleeping'
                return
            end
        end
        
        if not IsPedUsingAnyScenario(object.id) then
            TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_SITTING'), -1, true, false, false, false)
        end
    end

    function object:huntingTask()
        local target = 1000
        local closest = false
        
        if tablelength(object.huntingList) > 0 then
            for k, v in pairs(object.huntingList) do
                local eCoords = GetEntityCoords(k)
                local pCoords = GetEntityCoords(PlayerPedId())
                local dist = #(eCoords - pCoords)
                if dist < target then
                    target = dist
                    closest = k
                end
            end
        end

        if closest then
            local arrived = false
            
            Citizen.CreateThread(function()
                while not arrived and object.huntingList[closest] ~= 'found' do
                    Wait(10)
                    local cCoords = GetEntityCoords(closest)
                    local dCoords = object.pos
                    local dDist = #(cCoords - dCoords)
                    local barktime = 7000
                    
                    if dDist < 3 then
                        arrived = true
                        TaskStartScenarioInPlace(object.id, GetHashKey('WORLD_ANIMAL_DOG_BARKING_UP'), barktime, true, false, false, false)
                        Wait(barktime)
                        object.huntingList[closest] = 'found'
                        object.followTask()
                    end
                end
            end)

            if IsEntityDead(closest) and not arrived and object.huntingList[closest] ~= 'found' then
                Citizen.InvokeNative(0x6A071245EB0D1882, object.id, closest, -1, 2.4, 2.0, 0, 0)
            end
        end
    end

    -------------------------------------------------
    -- DEBUG (only when enabled)
    -------------------------------------------------
    if Config.Debug then
        Citizen.CreateThread(function()
            while object.spawned do
                Wait(1)
                DrawText(0.5, 0.02, 'Ped spawned: ' .. tostring(object.spawned))
                DrawText(0.5, 0.04, 'Ped model: ' .. tostring(object.model))
                DrawText(0.5, 0.06, 'Ped state: ' .. tostring(object.state))
                DrawText(0.5, 0.08, 'Ped name: ' .. tostring(object.name))
            end
        end)
    end

    return object
end
