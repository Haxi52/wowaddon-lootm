
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
        table.insert(lootTable, GetLootSlotLink(i));
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
    ["INVTYPE_SHIELD"]=17,
    ["INVTYPE_2HWEAPON"]=16,
    ["INVTYPE_WEAPONMAINHAND"]=16,
    ["INVTYPE_WEAPONOFFHAND"]=17,
    ["INVTYPE_HOLDABLE"]=17,
    ["INVTYPE_RANGED"]=18,
    ["INVTYPE_THROWN"]=18,
    ["INVTYPE_RANGEDRIGHT"]=18,
    ["INVTYPE_RELIC"]=18,
    ["INVTYPE_TABARD"]=19,
    };
    return {
        GetPlayerItemDetails = function (itemLink)
            local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
                GetItemInfo(itemLink);
            local playerSlot = inventoryMap[itemEquipLocation];
            local dataType = type(playerSlot);

            if (dataType == 'number') then
                return { GetInventoryItemLink('player', playerSlot) };
            elseif (dataType == 'table') then
                local output = {};
                for k,v in pairs(playerSlot) do
                    table.insert(output, GetInventoryItemLink('player', v));
                end
                return output;
            end
        end,
    };

end)();

-- LootM_Show
-- /lootm
SLASH_LOOTM1 = '/lootm';
SlashCmdList["LOOTM"] = function (message)
    if (string.sub(message, 1, 4) == 'test') then
        LootMComms.NewLoot({ string.sub(message, 5) });
    else
        LootMItemEntries.Show();
    end
end;


-- TODO: Accordian loot items (?)
-- compare against current equipped item
-- add stat weights into comparison
-- detect loot masterable items?
-- prevent more than one change in loot choice
-- prevent need on non-usable items
-- Loot master triggered only
-- assign loot
-- sort player roll list by 'need'
-- reset loot session (loot master button)
