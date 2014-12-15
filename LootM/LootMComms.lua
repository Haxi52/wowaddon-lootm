LootMComms = (function ()

    local raidMessageType = "RAID";
    local newLootPrefix = 'LootMNew';
    local newLootStartPrefix = 's';
    local newLootItemPrefix = 'i';
    local newLootEndPrefix = 'e';
    local rollPrefix = 'LootMRoll';
    local awardPrefix = 'LootMAward';

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

    local chatMessageEvent = function(prefix, message, distType, sender)
        local f = chatMessageHandlers[prefix];
        if (f) then f(message, sender); end;
    end;

    return {
        NewLoot = function(lootTable)
            local messagePrefix = newLootStartPrefix;
            for i,v in ipairs(lootTable) do
                SendAddonMessage(newLootPrefix, messagePrefix .. v, raidMessageType);
                messagePrefix = newLootItemPrefix;
            end
            messagePrefix = newLootEndPrefix;
            SendAddonMessage(newLootPrefix, messagePrefix, raidMessageType);
        end,
        Roll = function(rollId, itemLink, playerItems) 
            local playerItemsString = '';
            if (playerItems) then
                playerItemsString = ';' .. table.concat(playerItems, ';');
            end
            SendAddonMessage(rollPrefix, rollId .. itemLink .. playerItemsString, raidMessageType);
        end,
        Award = function(itemLink, awardee) return; end,
        MessageRecieved = chatMessageEvent,
    };

end)();