local Config = {
    MaxTransfer = 1000000000, -- hard cap per transfer
    CooldownMs  = 1500,       -- minimum time between transfer attempts per player
}

local busy = {}          -- [src] = true while a transfer is in progress
local lastAttempt = {}   -- [src] = GetGameTimer() of the last attempt

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastAttempt[src] = nil
end)

-- Get the player's citizenid from Qbox
local function getCitizenId(src)
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    local Player = exports.qbx_core:GetPlayer(src)
    return Player and Player.PlayerData.citizenid or nil
end

-- Get player's sCoin balance and citizen ID from database
RegisterNetEvent('scoin:getBalance', function()
    local src = source

    local player_identifier = getCitizenId(src)
    if not player_identifier then
        print('[sCoin] Could not find player identifier for:', src)
        TriggerClientEvent('scoin:receiveBalance', src, 0, nil)
        return
    end

    local balance = MySQL.scalar.await('SELECT crypto FROM ra_boosting_user_settings WHERE player_identifier = ?', {player_identifier}) or 0

    TriggerClientEvent('scoin:receiveBalance', src, balance, player_identifier)
end)

-- Does the actual transfer. Returns success, message, newSenderBalance
local function doTransfer(sender, target, amount)
    -- Recipient must be a real character
    local exists = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ?', {target})
    if not exists then
        return false, 'Recipient Citizen ID not found in server'
    end

    -- Make sure the recipient has a crypto row
    local hasRow = MySQL.scalar.await('SELECT player_identifier FROM ra_boosting_user_settings WHERE player_identifier = ?', {target})
    if not hasRow then
        local insertId = MySQL.insert.await('INSERT INTO ra_boosting_user_settings (player_identifier, crypto) VALUES (?, ?)', {target, 0})
        if not insertId then
            return false, 'Failed to create recipient crypto account'
        end
        print(('[sCoin] Created new crypto account for: %s'):format(target))
    end

    -- Atomic debit: only succeeds if the sender still has enough, so spamming can't double-spend
    local debited = MySQL.update.await(
        'UPDATE ra_boosting_user_settings SET crypto = crypto - ? WHERE player_identifier = ? AND crypto >= ?',
        {amount, sender, amount}
    )
    if debited ~= 1 then
        return false, 'Insufficient balance'
    end

    -- Atomic credit
    local credited = MySQL.update.await(
        'UPDATE ra_boosting_user_settings SET crypto = crypto + ? WHERE player_identifier = ?',
        {amount, target}
    )
    if credited ~= 1 then
        -- Refund the sender
        MySQL.update.await('UPDATE ra_boosting_user_settings SET crypto = crypto + ? WHERE player_identifier = ?', {amount, sender})
        return false, 'Failed to update recipient balance'
    end

    local newBalance = MySQL.scalar.await('SELECT crypto FROM ra_boosting_user_settings WHERE player_identifier = ?', {sender}) or 0
    return true, 'Transfer successful!', newBalance
end

-- Transfer sCoin to another player
RegisterNetEvent('scoin:transfer', function(targetCitizenId, amount)
    local src = source

    -- Rate limit / one transfer at a time per player
    local now = GetGameTimer()
    if busy[src] or (lastAttempt[src] and now - lastAttempt[src] < Config.CooldownMs) then
        TriggerClientEvent('scoin:transferResult', src, false, 'Please wait a moment')
        return
    end
    lastAttempt[src] = now

    local sender_identifier = getCitizenId(src)
    if not sender_identifier then
        print('[sCoin] Could not find sender identifier for:', src)
        TriggerClientEvent('scoin:transferResult', src, false, 'Could not identify sender')
        return
    end

    -- Validate amount: whole number, positive, within cap
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount <= 0 or amount ~= math.floor(amount) or amount > Config.MaxTransfer then
        TriggerClientEvent('scoin:transferResult', src, false, 'Invalid amount')
        return
    end

    -- Validate target citizen ID
    if type(targetCitizenId) ~= 'string' then
        TriggerClientEvent('scoin:transferResult', src, false, 'Invalid recipient Citizen ID')
        return
    end
    targetCitizenId = targetCitizenId:match('^%s*(.-)%s*$')
    if targetCitizenId == '' or #targetCitizenId > 50 then
        TriggerClientEvent('scoin:transferResult', src, false, 'Invalid recipient Citizen ID')
        return
    end

    if sender_identifier == targetCitizenId then
        TriggerClientEvent('scoin:transferResult', src, false, 'Cannot transfer to yourself')
        return
    end

    busy[src] = true
    local ok, success, message, newBalance = pcall(doTransfer, sender_identifier, targetCitizenId, amount)
    busy[src] = nil

    if not ok then
        print('[sCoin] Transfer error:', success)
        TriggerClientEvent('scoin:transferResult', src, false, 'Transfer failed')
        return
    end

    if not success then
        TriggerClientEvent('scoin:transferResult', src, false, message)
        return
    end

    print(('[sCoin] Transfer successful: %s sent %s sCoin to %s'):format(sender_identifier, amount, targetCitizenId))
    TriggerClientEvent('scoin:transferResult', src, true, message, newBalance)

    -- Notify recipient if they're online
    if GetResourceState('qbx_core') == 'started' then
        local Players = exports.qbx_core:GetQBPlayers()
        for playerId, player in pairs(Players) do
            if player.PlayerData.citizenid == targetCitizenId then
                TriggerClientEvent('scoin:transferNotification', playerId, sender_identifier, amount)
                break
            end
        end
    end
end)
