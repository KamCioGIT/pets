--[[
    Pet System - Wild West Edition
    Server Script
]]

local RSGCore = exports['rsg-core']:GetCoreObject()


Citizen.CreateThread(function()
    for petName, petConfig in pairs(Config.Pets) do
        RSGCore.Functions.CreateUseableItem(petName, function(source, item)
            local Player = RSGCore.Functions.GetPlayer(source)
            if not Player then return end
            
            -- Trigger client event with pet name and item info
            TriggerClientEvent('rsg-pets:client:callPet', source, petName, item.info, item.slot)
        end)
        
        if Config.Debug then
            -- print('[Pet System] Registered useable item: ' .. petName)
        end
    end
    
    print('[Pet System] Registered ' .. GetTableLength(Config.Pets) .. ' pet items')
end)


RegisterNetEvent('rsg-pets:server:updatePetName')
AddEventHandler('rsg-pets:server:updatePetName', function(petItemName, newName, slot)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Try to find item by slot first (more accurate), then by name
    local item = nil
    if slot then
        item = Player.PlayerData.items[slot]
    end
    
    if not item or item.name ~= petItemName then
        item = Player.Functions.GetItemByName(petItemName)
    end
    
    if item then
        -- Update item info directly for persistence
        item.info = item.info or {}
        item.info.petName = newName
        
        -- Save back to player data
        Player.PlayerData.items[item.slot] = item
        Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        
        if Config.Debug then
            print('[Pet System] Updated pet name for ' .. src .. ': ' .. newName .. ' in slot ' .. item.slot)
        end
    end
end)


RegisterNetEvent('rsg-pets:server:feedPet')
AddEventHandler('rsg-pets:server:feedPet', function(foodItem)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Check if food item is valid
    if not Config.PetFood[foodItem] then return end
    
    -- Remove the food item from inventory
    local hasItem = Player.Functions.GetItemByName(foodItem)
    if hasItem then
        Player.Functions.RemoveItem(foodItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[foodItem], 'remove')
    end
end)


RegisterNetEvent('rsg-pets:server:purchasePet')
AddEventHandler('rsg-pets:server:purchasePet', function(petName, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Validate pet exists
    local petConfig = Config.Pets[petName]
    if not petConfig then
        TriggerClientEvent('rsg-pets:client:purchaseResult', src, false, 'Invalid pet!')
        return
    end
    
    -- Validate price matches (security check)
    if petConfig.price ~= price then
        TriggerClientEvent('rsg-pets:client:purchaseResult', src, false, 'Price mismatch!')
        return
    end
    
    -- Check if player already owns a pet (only one pet allowed)
    -- Disabled: User wants to allow multiple pets in inventory
    -- for existingPetName, _ in pairs(Config.Pets) do
    --     local hasItem = Player.Functions.GetItemByName(existingPetName)
    --     if hasItem then
    --         TriggerClientEvent('rsg-pets:client:purchaseResult', src, false, 'You already own a pet! Only one pet allowed at a time.')
    --         return
    --     end
    -- end
    
    -- Check player has enough money
    local playerCash = Player.PlayerData.money.cash or 0
    
    if playerCash < price then
        TriggerClientEvent('rsg-pets:client:purchaseResult', src, false, 'Not enough money!')
        return
    end
    
    -- Remove money
    Player.Functions.RemoveMoney('cash', price, 'pet-purchase-' .. petName)
    
    -- Add pet item to inventory
    local added = Player.Functions.AddItem(petName, 1, nil, {
        purchased = os.time(),
        petName = petConfig.label
    })
    
    if added then
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[petName], 'add')
        TriggerClientEvent('rsg-pets:client:purchaseResult', src, true, string.format('You purchased a %s for $%s', petConfig.label, price))
        
        -- Update money display
        local newCash = Player.PlayerData.money.cash or 0
        TriggerClientEvent('rsg-pets:client:updateMoney', src, newCash)
        
        if Config.Debug then
            -- print('[Pet System] ' .. Player.PlayerData.charinfo.firstname .. ' purchased ' .. petName .. ' for $' .. price)
        end
    else
        -- Refund if item couldn't be added
        Player.Functions.AddMoney('cash', price, 'pet-purchase-refund')
        TriggerClientEvent('rsg-pets:client:purchaseResult', src, false, 'Inventory full!')
    end
end)


function GetTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
