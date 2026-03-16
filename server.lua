-- Get player's sCoin balance and citizen ID from database
RegisterNetEvent('scoin:getBalance', function()
    local src = source
    
    -- Get player_identifier from Qbox (citizenid)
    local player_identifier = nil
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if Player then
            player_identifier = Player.PlayerData.citizenid
        end
    end

    if not player_identifier then
        print('[sCoin] Could not find player identifier for:', src)
        TriggerClientEvent('scoin:receiveBalance', src, 0, nil)
        return
    end

    -- Query database for crypto balance
    MySQL.query('SELECT crypto FROM ra_boosting_user_settings WHERE player_identifier = ?', {player_identifier}, function(result)
        local balance = 0
        
        if result and result[1] then
            balance = result[1].crypto or 0
        end
        
        print(('[sCoin] Player %s balance: %s'):format(player_identifier, balance))
        TriggerClientEvent('scoin:receiveBalance', src, balance, player_identifier)
    end)
end)

-- Transfer sCoin to another player
RegisterNetEvent('scoin:transfer', function(targetCitizenId, amount)
    local src = source
    
    -- Get sender's player_identifier from Qbox (citizenid)
    local sender_identifier = nil
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if Player then
            sender_identifier = Player.PlayerData.citizenid
        end
    end

    if not sender_identifier then
        print('[sCoin] Could not find sender identifier for:', src)
        TriggerClientEvent('scoin:transferResult', src, false, 'Could not identify sender')
        return
    end

    -- Validate amount
    if not amount or amount <= 0 then
        TriggerClientEvent('scoin:transferResult', src, false, 'Invalid amount')
        return
    end

    -- Validate target citizen ID
    if not targetCitizenId or targetCitizenId == '' then
        TriggerClientEvent('scoin:transferResult', src, false, 'Invalid recipient Citizen ID')
        return
    end

    -- Check if sender is trying to send to themselves
    if sender_identifier == targetCitizenId then
        TriggerClientEvent('scoin:transferResult', src, false, 'Cannot transfer to yourself')
        return
    end

    -- Check sender's balance
    MySQL.query('SELECT crypto FROM ra_boosting_user_settings WHERE player_identifier = ?', {sender_identifier}, function(senderResult)
        if not senderResult or not senderResult[1] then
            TriggerClientEvent('scoin:transferResult', src, false, 'Could not retrieve your balance')
            return
        end

        local senderBalance = senderResult[1].crypto or 0

        if senderBalance < amount then
            TriggerClientEvent('scoin:transferResult', src, false, 'Insufficient balance')
            return
        end

        -- First, check if recipient citizen ID exists in the server (validate it's a real player)
        MySQL.query('SELECT citizenid FROM players WHERE citizenid = ?', {targetCitizenId}, function(playerCheck)
            if not playerCheck or not playerCheck[1] then
                TriggerClientEvent('scoin:transferResult', src, false, 'Recipient Citizen ID not found in server')
                return
            end

            -- Check if recipient has a crypto account, create one if they don't
            MySQL.query('SELECT crypto FROM ra_boosting_user_settings WHERE player_identifier = ?', {targetCitizenId}, function(recipientResult)
                local recipientBalance = 0
                
                if not recipientResult or not recipientResult[1] then
                    -- Recipient exists in players table but has no crypto record yet, create one
                    MySQL.insert('INSERT INTO ra_boosting_user_settings (player_identifier, crypto) VALUES (?, ?)', {targetCitizenId, 0}, function(insertId)
                        if not insertId then
                            TriggerClientEvent('scoin:transferResult', src, false, 'Failed to create recipient crypto account')
                            return
                        end
                        print(('[sCoin] Created new crypto account for: %s'):format(targetCitizenId))
                        
                        -- Now perform the transfer with recipientBalance = 0
                        performTransfer(src, sender_identifier, targetCitizenId, senderBalance, 0, amount)
                    end)
                    return
                else
                    recipientBalance = recipientResult[1].crypto or 0
                    -- Perform the transfer
                    performTransfer(src, sender_identifier, targetCitizenId, senderBalance, recipientBalance, amount)
                end
            end)
        end)
    end)
end)

-- Helper function to perform the actual transfer
function performTransfer(src, sender_identifier, targetCitizenId, senderBalance, recipientBalance, amount)
    local newSenderBalance = senderBalance - amount
    local newRecipientBalance = recipientBalance + amount

    -- Update sender's balance
    MySQL.update('UPDATE ra_boosting_user_settings SET crypto = ? WHERE player_identifier = ?', {newSenderBalance, sender_identifier}, function(senderUpdated)
        if not senderUpdated then
            TriggerClientEvent('scoin:transferResult', src, false, 'Failed to update sender balance')
            return
        end

        -- Update recipient's balance
        MySQL.update('UPDATE ra_boosting_user_settings SET crypto = ? WHERE player_identifier = ?', {newRecipientBalance, targetCitizenId}, function(recipientUpdated)
            if not recipientUpdated then
                -- Rollback sender's balance
                MySQL.update('UPDATE ra_boosting_user_settings SET crypto = ? WHERE player_identifier = ?', {senderBalance, sender_identifier})
                TriggerClientEvent('scoin:transferResult', src, false, 'Failed to update recipient balance')
                return
            end

            -- Transfer successful
            print(('[sCoin] Transfer successful: %s sent %s sCoin to %s'):format(sender_identifier, amount, targetCitizenId))
            TriggerClientEvent('scoin:transferResult', src, true, 'Transfer successful!', newSenderBalance)

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
    end)
end