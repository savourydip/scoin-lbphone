-- Register NUI callback BEFORE adding the app
RegisterNUICallback('getBalance', function(data, cb)
    TriggerServerEvent('scoin:getBalance')
    cb('ok')
end)

-- Register NUI callback for transfers
RegisterNUICallback('transfer', function(data, cb)
    print('[sCoin] Transfer request:', data.citizenId, data.amount)
    TriggerServerEvent('scoin:transfer', data.citizenId, tonumber(data.amount))
    cb('ok')
end)

-- Receive balance from server and send to UI using LB Phone's custom app message
RegisterNetEvent('scoin:receiveBalance', function(balance, citizenId)
    exports['lb-phone']:SendCustomAppMessage('scoin', {
        action = 'updateBalance',
        balance = balance,
        citizenId = citizenId
    })
end)

-- Receive transfer result from server
RegisterNetEvent('scoin:transferResult', function(success, message, newBalance)
    print('[sCoin] Transfer result:', success, message)
    exports['lb-phone']:SendCustomAppMessage('scoin', {
        action = 'transferResult',
        success = success,
        message = message,
        newBalance = newBalance
    })
end)

-- Receive notification when someone sends you sCoin
RegisterNetEvent('scoin:transferNotification', function(senderCitizenId, amount)
    print('[sCoin] Received transfer notification from:', senderCitizenId, 'Amount:', amount)
    exports['lb-phone']:SendCustomAppMessage('scoin', {
        action = 'receiveNotification',
        senderCitizenId = senderCitizenId,
        amount = amount
    })
    
    -- You can also add a phone notification here if LB Phone supports it
    -- exports['lb-phone']:SendNotification({
    --     app = 'sCoin',
    --     title = 'sCoin Received',
    --     content = ('You received %s sCoin from %s'):format(amount, senderCitizenId)
    -- })
end)

-- Add the sCoin app to LB Phone
CreateThread(function()
    while GetResourceState('lb-phone') ~= 'started' do
        Wait(500)
    end
    
    Wait(500) -- Extra wait to ensure lb-phone exports are ready
    
    local added = exports['lb-phone']:AddCustomApp({
        identifier = 'scoin',
        name = 'sCoin',
        description = 'Check your sCoin crypto balance',
        developer = 'Your Server',
        defaultApp = false,
        size = 150,
        price = 0,
        images = {'https://kappa.lol/ooCi0q'},
        ui = 'scoin-lbphone/ui/index.html',
        icon = 'https://kappa.lol/ooCi0q'
    })

    if added then
        print('[sCoin] App successfully added to LB Phone')
    else
        print('[sCoin] Failed to add app to LB Phone')
    end
end)
