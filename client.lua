local RESOURCE = GetCurrentResourceName()
local APP_ID = 'scoin'

local function usingSD() return GetResourceState('sd-phone') == 'started' end
local function phoneStarted()
    return usingSD() or GetResourceState('lb-phone') == 'started'
end

local function sendToApp(action, data)
    local payload = { action = action, data = data }
    if usingSD() then
        exports['sd-phone']:sendCustomAppMessage(APP_ID, payload)
    else
        exports['lb-phone']:SendCustomAppMessage(APP_ID, payload)
    end
end

RegisterNUICallback('getBalance', function(_, cb)
    TriggerServerEvent('scoin:getBalance')
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    local amount = math.floor(tonumber(data.amount) or 0)
    TriggerServerEvent('scoin:transfer', data.citizenId, amount)
    cb('ok')
end)

RegisterNetEvent('scoin:receiveBalance', function(balance, citizenId)
    sendToApp('updateBalance', { balance = balance, citizenId = citizenId })
end)

RegisterNetEvent('scoin:transferResult', function(success, message, newBalance)
    sendToApp('transferResult', { success = success, message = message, newBalance = newBalance })
end)

RegisterNetEvent('scoin:transferNotification', function(senderCitizenId, amount)
    sendToApp('receiveNotification', { senderCitizenId = senderCitizenId, amount = amount })
end)

local function registerApp()
    local app = {
        identifier  = APP_ID,
        name        = 'sCoin',
        description = 'Check your sCoin crypto balance',
        developer   = 'Your Server',
        defaultApp  = false, -- true = pre-installed, false = App Store download
        size        = 150,
        price       = 0,
        images      = { 'https://kappa.lol/ooCi0q' },
        icon        = 'https://kappa.lol/ooCi0q',
        ui          = RESOURCE .. '/ui/index.html',
    }

    local ok, err
    if usingSD() then
        ok, err = exports['sd-phone']:addCustomApp(app)
    else
        ok, err = exports['lb-phone']:AddCustomApp(app)
    end
    print(ok and '[sCoin] App registered' or ('[sCoin] Registration failed: ' .. tostring(err)))
end

CreateThread(function()
    while not phoneStarted() do Wait(500) end
    Wait(1000)
    registerApp()
end)

-- Registrations live in the phone's memory, so re-register if it restarts
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'sd-phone' and resource ~= 'lb-phone' then return end
    Wait(1000)
    registerApp()
end)
