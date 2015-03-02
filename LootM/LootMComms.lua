-- fortunatly the communication requirements for this are fairly straight forward, so the formatting is rutamentry
local versionCheck = false;
LootMComms =( function()

    --local raidMessageType = "OFFICER";
    -- changed for testing
    local raidMessageType = "RAID";
    local newLootPrefix = 'LootMNew';
    local rollPrefix = 'LootMRoll';
    local awardPrefix = 'LootMAward';
    local versionPingPrefix = 'LootMvPing';
    local versionPingPrefix = 'LootMvPong';
    local newLootMessageSpool = {};
    local pendingMessages = { };

    local function processNewLootMessage(itemCount)
        debug('processNewLootMessage');
        -- deturmins if the new loot spool has all the items expected then calls out for the items to be loaded
        if (not newLootMessageSpool) then
            newLootMessageSpool = {};
            return;
        end
        local i =0;
        for x in pairs(newLootMessageSpool) do
            i = i + 1;
        end
        if (i ~= itemCount) then
            return;
        end

        LootMItemEntries.Hide();
        for k,itemLink in pairs(newLootMessageSpool) do
            local playerDetails = LootMItemEvaluator.GetPlayerItemDetails(itemLink);

            LootMItemEntries.ShowItem(itemLink, playerDetails);    
        end    
        LootMItemEntries.Show();
        print('[LootM] Staring new loot session. ' .. LootM.RandomLootText());
        PlaySound("LOOTWINDOWOPENEMPTY");
    end

    
    -- a dictionary of message prefixes (used as message type) and funtions to handle/parse the message
    -- see below for the format of each message type
    local chatMessageHandlers = {
        [newLootPrefix] = function(message, sender)
            debug('LootComms: new loot recieved');
            local parsedMessage = {};
            for i in string.gmatch(message, "([^;]+)") do
                table.insert(parsedMessage, i);
            end
            local messageCount, messageIndex, itemLink = unpack(parsedMessage);
            messageCount, messageIndex = tonumber(messageCount), tonumber(messageIndex);
            if (newLootMessageSpool[messageIndex]) then
                -- this shoudnt happen
                newLootMessageSpool = {};
            end

            -- if the item is not loaded, pend the message until the server can get us info about the item
            if (not GetItemInfo(itemLink)) then
                debug('item not loaded, queing');
                table.insert(pendingMessages,
                {
                    LoadItems = { itemLink },
                    MessageType = newLootPrefix,
                    Message = message,
                    Sender = sender,
                });
                return;
            end

            newLootMessageSpool[messageIndex] = itemLink;
            processNewLootMessage(messageCount);
        end,
        [rollPrefix] = function(message, sender)
            debug('LootComms: roll recieved');
            debug(message);
            local parsedMessage = {};
            for i in string.gmatch(message, "([^;]+)") do
                table.insert(parsedMessage, i);
            end
            local rollId, role, itemLink, improvementRating, playerItems = (function(a, b, c, d, ...)
                return a,b,c,d,{...};
            end)(unpack(parsedMessage));

            -- We are not short-circuting this logic because we want to make sure all
            -- items are being requested from the server.
            local requiresItemLoad, loadItems = false, {};
            if (not GetItemInfo(itemLink)) then
                requiresItemLoad = true;
                table.insert(loadItems, itemLink);
            end
            for k,item in pairs(playerItems) do
                if (not GetItemInfo(item)) then
                    requiresItemLoad = true;
                    table.insert(loadItems, itemLink);
                end
            end

            if (requiresItemLoad) then
                debug('LootComms: roll recieved -> Requires item load');
                table.insert(pendingMessages,
                {
                    LoadItems = loadItems,
                    MessageType = rollPrefix,
                    Message = message,
                    Sender = sender,
                });
                return;
            end

            LootMItemEntries.SetPlayerRoll(itemLink, sender, role, rollId, playerItems, improvementRating);
        end,
        [awardPrefix] = function(message, sender) 
            local parsedMessage = {};
            for i in string.gmatch(message, "([^;]+)") do
                table.insert(parsedMessage, i);
            end
            local awardee, itemLink = unpack(parsedMessage);
            LootMItemEntries.AwardItem(itemLink, awardee);
            print(awardee..' was awarded '..itemLink);
        end,
        [versionPingPrefix] = function(message, sender)
            SendAddonMessage(versionPongPrefix, lootmVersion, raidMessageType);
        end,
        [versionPongPrefix] = function(message, sender)
            LootM.RaidVersion[sender] = message;
            local otherVersion = tonumber(message:gsub("%.", ""));
            local myVersion = tonumber(GetAddOnMetadata("LootM", "Version"):gsub("%.", ""));
            if (otherVersion > myVersion and not versionCheck) then
                versionCheck = true;
                print("[LootM] A new version is available! (" .. message .. ")");
            end
        end,
    };

    -- main event handler which dispatches the message to a handler based on prefix
    local chatMessageEvent = function(prefix, message, distType, sender)
        if (not raidMessageType == distType) then return end;
        local f = chatMessageHandlers[prefix];
        if (f) then f(message, sender); end;
    end;

    local itemsLoaded = function()
        debug('items loaded');
        if (not (#pendingMessages > 0)) then return; end

        -- check each pending message and see that the items are loaded
        for k,v in pairs(pendingMessages) do           
            for i,j in pairs(pendingMessages[k].LoadItems) do
                if (not GetItemInfo(j)) then 
                    return;
                end
            end
        end

        -- swap out the table so we can process the messages
        local messages = pendingMessages;
        pendingMessages = {};
        -- re call into each handler, if the item is still not loaded it will reque the message.
        for k,v in pairs(messages) do
            local f = chatMessageHandlers[v.MessageType];
            if (f) then 
                f(v.Message, v.Sender); 
            end
        end
    end

    for k,v in pairs(chatMessageHandlers) do
        RegisterAddonMessagePrefix(k);
    end

    return {
        -- signals to raid members new lootable items are available from the loot master
        NewLoot = function(lootTable)
            debug('LootCooms: newloot');
            local lootCount = #lootTable;
            for i, v in ipairs(lootTable) do
                -- [total messages];[this message index];[item link]
                SendAddonMessage(
                    newLootPrefix, 
                    table.concat({lootCount, i, v}, ";"),
                    raidMessageType);
            end
        end,

        -- singles a player's roll selection on a item being looted
        Roll = function(rollId, itemLink, playerDetails)
            debug('LootCooms: Roll');
            local role = select(6, GetSpecializationInfoByID(LootM.GetLootSpecId()));
            local message = { rollId, role, itemLink, playerDetails.ImprovementRaiting };
            for k,v in pairs(playerDetails.PlayerItems) do
                table.insert(message, v);
            end
            -- [rollid];[item being rolled on];[improvementrating];[table...of player equipped items]
            SendAddonMessage(rollPrefix, table.concat(message, ';'), raidMessageType);
        end,
        Award = function(itemLink, awardee) 
            local message = { awardee, itemLink }
            SendAddonMessage(awardPrefix, table.concat(message, ';'), raidMessageType);
        end,
        VersionCheck = function()
            SendAddonMessage(versionPingPrefix, lootmVersion, raidMessageType);
        end,

        MessageRecieved = chatMessageEvent,-- proxy to publically expose the handler
        ItemsLoaded = itemsLoaded, -- proxy for even when item data is received from server

    };

end )();