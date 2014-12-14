
seterrorhandler(print);

local lootSession = { };

LootMFrames = { };
LootMEvents = { };

local LootM = CreateFrame("FRAME", "LootM"), { };

LootMFrames["LootM"] = LootM;

function LootMEvents:LOOT_OPENED(...)
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

-- LootM_Show
-- /lootm
SLASH_LOOTM1 = '/lootm';
SlashCmdList["LOOTM"] = function (message)
    LootMItemEntries.Show();
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