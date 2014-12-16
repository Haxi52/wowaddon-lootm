seterrorhandler(print);

LootMFrames = { };
LootMEvents = { };
LootMItemEvaluator = {};

local LootM = CreateFrame("FRAME", "LootM"), { };

LootMFrames["LootM"] = LootM;

function LootMEvents:LOOT_OPENED(...)
    if (not LootM.IsEnabled() or not LootM.IsLootMaster()) then return; end;
    local lootTable = { };
    for i = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(i);
        _, _, itemRarity = GetItemInfo(itemLink);
        if (itemRarity >= GetLootThreshold()) then
            table.insert(lootTable, itemLink);
        end
    end
    if (LootMItemEntries.IsNewLoot(lootTable)) then 
        LootMComms.NewLoot(lootTable);
    end
end

function LootMEvents:LOOT_CLOSED(...)
    
end

function LootMEvents:CHAT_MSG_ADDON(...)
    LootMComms.MessageRecieved(...);
end

LootM:SetScript("OnEvent", function(self, event, ...)
    LootMEvents[event](self, ...);
end );

for k, v in pairs(LootMEvents) do
    LootM:RegisterEvent(k);
end

LootM.IsEnabled = function()
    return(IsInRaid() and 'master' == GetLootMethod())
end

LootM.IsLootMaster = function()
    local masterLooterId = select(3, GetLootMethod());
    if masterLooterId then
        return GetRaidRosterInfo(masterLooterId) == GetUnitName("player");
    end
    return false;
end


function RegisterFrame(frame)
    if (frame == nil or not frame:GetName()) then return; end
    local frameName = frame:GetName();
    LootMFrames[frameName] = frame;

    if (LootMEvents[frameName .. '_OnLoad']) then
        LootMEvents[frameName .. '_OnLoad'](self, frame);
    end
end


LootMItemEvaluator = (function ()

    local inventoryMap = {
    ["INVTYPE_AMMO"]=0,
    ["INVTYPE_HEAD"]=1,
    ["INVTYPE_NECK"]=2,
    ["INVTYPE_SHOULDER"]=3,
    ["INVTYPE_BODY"]=4,
    ["INVTYPE_CHEST"]=5,
    ["INVTYPE_ROBE"]=5,
    ["INVTYPE_WAIST"]=6,
    ["INVTYPE_LEGS"]=7,
    ["INVTYPE_FEET"]=8,
    ["INVTYPE_WRIST"]=9,
    ["INVTYPE_HAND"]=10,
    ["INVTYPE_FINGER"]={11,12},
    ["INVTYPE_TRINKET"]={13,14},
    ["INVTYPE_CLOAK"]=15,
    ["INVTYPE_WEAPON"]={16,17},
    ["INVTYPE_SHIELD"]={16,17},
    ["INVTYPE_2HWEAPON"]={16,17},
    ["INVTYPE_WEAPONMAINHAND"]={16,17},
    ["INVTYPE_WEAPONOFFHAND"]={16,17},
    ["INVTYPE_HOLDABLE"]={16,17},
    ["INVTYPE_RANGED"]=18,
    ["INVTYPE_THROWN"]=18,
    ["INVTYPE_RANGEDRIGHT"]=18,
    ["INVTYPE_RELIC"]=18,
    ["INVTYPE_TABARD"]=19,
    };

    local function getItemValue(itemLink, weightTable)
        local itemStats = GetItemStats(itemLink);
        local itemValue =0;
        for k,v in pairs(statTable) do
            local weight = weightTable[k];
            if (weight and weight >=0) then
                itemValue = itemValue + (v * weight);
            end
        end
        return itemValue;
    end;

    local function getImprovementRating(equippedValue, newValue)
        local value =0;
        if (equippedValue > 0 and newValue > 0) then
            value = (newValue - equippedValue) / equippedValue;
            value = math.max(0, value);
            value = value * 100;
        end
        return value;
    end

    return {
        GetPlayerItemDetails = function (itemLink)
            local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
                GetItemInfo(itemLink);
            local playerSlot = inventoryMap[itemEquipLocation];
            local dataType = type(playerSlot);
            local output = {};

            if (dataType == 'number') then
                table.insert(output, GetInventoryItemLink('player', playerSlot));
            elseif (dataType == 'table') then
                for k,v in pairs(playerSlot) do
                    local equippedItemLink = GetInventoryItemLink('player', v);
                    if (equippedItemLink) then
                        table.insert(output, equippedItemLink);
                    end
                end
            end

            local improvementRating =0;
            for k,v in pairs(output) do
                local old = getItemValue(itemLink, LootMStatWeights[1]);
                local new = getItemValue(v, LootMStatWeights[1]);
                improvementRating = math.max(
                    getImprovementRating(old, new),
                    improvementRating);
            end

            return output, improvementRating;
        end,
        GetItemValue = function(itemLink, weightTable)
            return getItemValue(itemLink, weightTable);
        end,
    };

end)();

-- LootM_Show
-- /lootm
SLASH_LOOTM1 = '/lootm';
SlashCmdList["LOOTM"] = function (message)
    if (string.sub(message, 1, 4) == 'test') then
        LootMComms.NewLoot({ string.sub(message, 5) });
    elseif (string.sub(message, 1, 4) == 'need') then
        local x = LootMItemEntries.GetItems();
        LootMItemEntries.SetPlayerRoll(x[1], 'TheNewGuy', '1', LootMItemEvaluator.GetPlayerItemDetails(x[1]));
    elseif (string.sub(message, 1, 4) == 'gree') then
        local x = LootMItemEntries.GetItems();
        LootMItemEntries.SetPlayerRoll(x[1], 'TheNewGuy', '2', LootMItemEvaluator.GetPlayerItemDetails(x[1]));
    else
        LootMItemEntries.Show();
    end
end;

-- table sort iterator
-- http://stackoverflow.com/a/15706820
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end


-- TODO: Accordian loot items (?)
-- add stat weights into comparison (left is to propegate to display)
-- edit stat weights
-- prevent more than one change in loot choice
-- prevent need on non-usable items
-- assign loot
-- reset loot session (loot master button)

-- for debugging
function PrintTable(t)
    for k,v in pairs(t) do
        print(k..": "..v);
    end
end