-- Import the license key from auth.lua
local Auth = require('auth')
local API_URL = "http://185.228.82.254:80/licenses/validate/"  -- Replace with your actual API URL

-- Function to validate the license key
local function ValidateLicense()
    local licenseKey = Auth.LICENSE_KEY
    local validLicense = false

    -- Perform an HTTP request to validate the license key
    PerformHttpRequest(API_URL .. licenseKey, function(statusCode, responseText, headers)
        if statusCode == 200 then
            local response = json.decode(responseText)
            if response and response.data and response.data.valid then
                print("^2[INFO] ^7License key is valid.")
                validLicense = true
            else
                print("^1[ERROR] ^7License key is invalid.")
                -- Notify all clients to stop running the resource
                TriggerClientEvent('ux-starterpack:LicenseInvalid', -1)
                StopResource(GetCurrentResourceName())  -- Stop the resource if the license is invalid
            end
        else
            print("^1[ERROR] ^7Error validating license. Status code: " .. statusCode)
            -- Notify all clients to stop running the resource
            TriggerClientEvent('ux-starterpack:LicenseInvalid', -1)
            StopResource(GetCurrentResourceName())  -- Stop the resource if validation fails
        end
    end, "GET")

    return validLicense
end

-- Validate license on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if not ValidateLicense() then
            print("^1[ERROR] ^7Stopping resource due to invalid license.")
        end
    end
end)

-- Main Script Code

Core, Framework = GetCore()

lib.callback.register('ux-starterpack:CheckPlayer', function(source)
    local Player = Framework == "esx" and Core.GetPlayerFromId(source) or Core.Functions.GetPlayer(source)
    local identifier = Framework == "esx" and Player.identifier or Player.PlayerData.citizenid

    local query = "SELECT * FROM ux_starterpack WHERE identifier = ?"
    local params = { identifier }

    local response = FetchQuery(query, params)
    if not response or #response == 0 then
        if Config.Debug then print("^1[DEBUG] ^7Player not found in the database, adding them now") end

        local insertQuery = "INSERT INTO ux_starterpack (identifier, received) VALUES (?, ?)"
        local insertParams = { identifier, 0 }

        InsertQuery(insertQuery, insertParams, function(rowsAffected)
            if rowsAffected > 0 then
                if Config.Debug then print("^2[DEBUG] ^7Added new row for player: " .. identifier) end
            else
                if Config.Debug then print("^1[DEBUG] ^7Failed to add new row for player: " .. identifier) end
            end
        end)

        return true
    else
        for i = 1, #response do
            local row = response[i]
            if not row.received then
                return true
            else
                return false
            end
        end
    end
end)

local function SendDiscordLog(source, desc)
    local time = os.date("%c")
    local webhook = DiscordConfig.webhook
    local title = DiscordConfig.title
    local thumbnail_url = DiscordConfig.thumbnail
    local color = DiscordConfig.color

    if not webhook then
        print("^1[ERROR] ^7Discord Webhook is not set")
        return
    end

    if Config.Debug then print("^1[DEBUG] ^7Sending Discord Log") end

    local embed = {
        {
            ["author"] = {
                ["name"] = "UX Development",
                ["icon_url"] = "https://cdn.discordapp.com/attachments/1061739361474977962/1290319984156741684/asdasd.png",
            },
            ["color"] = tonumber(color),
            ["title"] = title,
            ["description"] = desc,
            ["thumbnail"] = {
                ["url"] = thumbnail_url,
            },
            ["fields"] = {
                {
                    ["name"] = "Player: ",
                    ["value"] = "```" .. GetPlayerName(source) .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "Server ID: ",
                    ["value"] = "```" .. source .. "```",
                    ["inline"] = true
                },
                {
                    ["name"] = "License ID:",
                    ["value"] = "```" .. GetPlayerIdentifiers(source)[1] .. "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "Time",
                    ["value"] = time,
                    ["inline"] = true
                },
            },
            ["timestamp"] = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            ["footer"] = {
                ["text"] = "Powered by UX Development",
                ["icon_url"] = "https://cdn.discordapp.com/attachments/1061739361474977962/1290319984156741684/asdasd.png",
            },
        }
    }
    PerformHttpRequest(webhook,
        function(err, text, headers) end, 'POST', json.encode({ embeds = embed }),
        { ['Content-Type'] = 'application/json' })
end

function UpdateRecevied(Player)
    local identifier = Framework == "esx" and Player.identifier or Player.PlayerData.citizenid
    local currentDate = os.date("%m/%d/%Y")
    local query = "UPDATE ux_starterpack SET received = ?, date_received = ? WHERE identifier = ?"
    local params = { 1, currentDate, identifier }

    ExecuteQuery(query, params)

    if Config.Debug then print("^2[DEBUG] ^7Updated received status for player: " .. identifier) end
end

RegisterServerEvent("ux-starterpack:ClaimVehicle")
AddEventHandler("ux-starterpack:ClaimVehicle", function(vehicleData)
    local Player = Framework == "esx" and Core.GetPlayerFromId(source) or Core.Functions.GetPlayer(source)
    local identifier = Framework == "esx" and Player.identifier or Player.PlayerData.citizenid

    if Framework == 'esx' then
        local query = "INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)"
        local params = {
            ['@owner'] = identifier,
            ['@plate'] = vehicleData.props.plate,
            ['@vehicle'] = json.encode(vehicleData.props)
        }
        InsertQuery(query, params)
    else
        local query =
        "INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage) VALUES (@license, @citizenid, @vehicle, @hash, @mods, @plate, @garage)"
        local params = {
            ['@license'] = Player.PlayerData.license,
            ['@citizenid'] = identifier,
            ['@vehicle'] = Config.StarterVehicle.model,
            ['@hash'] = GetHashKey(vehicleData.props.model),
            ['@mods'] = '{}',
            ['@plate'] = vehicleData.props.plate,
            ['@garage'] = 'pillboxgarage'
        }
        InsertQuery(query, params)
    end
end)

RegisterServerEvent("ux-starterpack:ClaimStarterpack")
AddEventHandler("ux-starterpack:ClaimStarterpack", function()
    local src = source
    local Player = Framework == "esx" and Core.GetPlayerFromId(src) or Core.Functions.GetPlayer(src)

    for i = 1, #Config.StarterPackItems do
        local item = Config.StarterPackItems[i].item
        local amount = Config.StarterPackItems[i].amount

        if Config.InventoryResource == 'ox_inventory' and GetResourceState(Config.InventoryResource) == 'started' then
            local success, response = exports.ox_inventory:AddItem(src, item, amount)
            if not success then
                if response == 'invalid_item' then
                    print("^1[ERROR] ^7Invalid item: " .. item)
                end
            end
        elseif Config.InventoryResource == 'qb-inventory' or Config.InventoryResource == 'ps-inventory' and GetResourceState(Config.InventoryResource) == 'started' then
            local itemInfo = Core.Shared.Items[item]
            if itemInfo then
                Player.Functions.AddItem(item, amount)
                TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, 'add', amount)
            else
                print("^1[ERROR] ^7Invalid item: " .. item)
            end
        elseif Config.InventoryResource == 'qs-inventory' and GetResourceState(Config.InventoryResource) == 'started' then
            exports['qs-inventory']:AddItem(src, item, amount)
            -- I don't have qs-inventory so I can't test this, and add error handling for this
        else
            error(Config.InventoryResource .. " is not found or not started", 2)
        end
    end

    UpdateRecevied(Player)
    SendDiscordLog(src, "Player has received their starter pack")
    Config.Notification(Config.Locale[Config.Lang]['success'], 'success', true, source)
end)
