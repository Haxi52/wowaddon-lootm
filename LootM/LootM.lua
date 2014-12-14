local lootSession = { };

--[[
lootSession =
    [instance.mapid]
    {
        Boss[BossId] = (bossid = UnitGUID('unit'))
        {
            Name = GetUnitName('unit')
            Slot[slot#]
            {
                SlotNumber,
                ItemId,
                ItemiLvl
                ItemSlotType --head,neck etc.
                Player[PlayerName]
                {
                    PlayerName,
                    AverageiLvl,
                    SlotiLvl,
                    Action, -- need/greed/pass
                    Roll, -- random number used for tie breaker
                    IsAwarded
                }
            }
        }
    }
--]]

LootMFrames = { };
LootMEvents = { };

local LootM = CreateFrame("FRAME", "LootM"), { };

LootMFrames["LootM"] = LootM;

function LootMEvents:LOOT_OPENED(...)
    local lootTable = { };
    for i = 1, GetNumLootItems() do
        table.insert(lootTable, GetLootSlotLink(i));
    end
    -- TODO: before sending comms for new loot, double check its a new set of loot items.
    LootMComms.NewLoot(lootTable);
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