-- fortunatly the communication requirements for this are fairly straight forward, so the formatting is rutamentry

LootMComms = (function ()

    local raidMessageType = "OFFICER"; -- changed for testing
    --local raidMessageType = "RAID";
    local newLootPrefix = 'LootMNew';
    local newLootStartPrefix = 's';
    local newLootItemPrefix = 'i';
    local newLootEndPrefix = 'e';
    local rollPrefix = 'LootMRoll';
    local awardPrefix = 'LootMAward';

    -- a dictionary of message prefixes (used as message type) and funtions to handle/parse the message
    -- see below for the format of each message type
    local chatMessageHandlers = {
        [newLootPrefix] = function (message, sender)
            local prefix = string.sub(message, 1, 1);
            if (prefix == newLootStartPrefix) then LootMItemEntries.Hide(); end;
            if (prefix == newLootEndPrefix) then
                LootMItemEntries.Show();
                print('[LootM] Staring new loot session. Take a gandar');
                return;
            end;
            LootMItemEntries.ShowItem(string.sub(message, 2));
        end,
        [rollPrefix] = function (message, sender) 
            local roll = string.sub(message, 1, 1);
            local itemsTable = {}; 
            local firstItem = nil;
            for item in string.gmatch(string.sub(message, 2), '([^;]+)') do
                if (not firstItem) then 
                    firstItem = item; 
                else
                    table.insert(itemsTable, item);
                end
            end
            LootMItemEntries.SetPlayerRoll(firstItem, sender, roll, itemsTable);
        end,
        [awardPrefix] = function (message, sender) return; end,
    };

    -- main event handler which dispatches the message to a handler based on prefix
    local chatMessageEvent = function(prefix, message, distType, sender)
        local f = chatMessageHandlers[prefix];
        if (f) then f(message, sender); end;
    end;

    return {
        -- signals to raid members new lootable items are available from the loot master
        -- Message format: [prefix][itemlink]
        -- where [prefix] is a single character (see above for values)
        -- single the start of a list, a list item, and finally a terminator
        -- [itemlink] taken as the remainder of the message string
        NewLoot = function(lootTable)
            local messagePrefix = newLootStartPrefix;
            for i,v in ipairs(lootTable) do
                SendAddonMessage(newLootPrefix, messagePrefix .. v, raidMessageType);
                messagePrefix = newLootItemPrefix;
            end
            messagePrefix = newLootEndPrefix;
            SendAddonMessage(newLootPrefix, messagePrefix, raidMessageType);
        end,
        -- singles a player's roll selection on a item being looted
        -- format is [RoleId][itemlink][playeritems][improvementraiting]
        -- rollid represents the roll action taken (need/greed/etc)
        -- itemlink is the item link of the looted item being rolled on (recieved from newloot)
        -- playeritems ';' delemited list of items the player has currently equipped
        Roll = function(rollId, itemLink, playerItems) 
            local playerItemsString = '';
            if (playerItems) then
                playerItemsString = ';' .. table.concat(playerItems, ';');
            end
            SendAddonMessage(rollPrefix, rollId .. itemLink .. playerItemsString, raidMessageType);
        end,
        -- TODO: Implement award
        Award = function(itemLink, awardee) return; end,
        MessageRecieved = chatMessageEvent, -- proxy to publically expose the handler
    };

end)();