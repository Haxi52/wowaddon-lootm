
local rollTextures = {
    ['0'] = 'Interface\\Buttons\\UI-GroupLoot-Pass-Up',
    ['1'] = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up',
    ['2'] = 'Interface\\Buttons\\UI-GroupLoot-Coin-Up',
};

local LootItemEntryFactory;
LootMItemEntries = {};

-- closure of player frame (each player listed under the loot item)
local playerFrameFactory = function (parent, previousEntry, playerName, rollId)
    local frame = CreateFrame('Button', nil, parent, 'PlayerRollDetail');
    if (previousEntry) then
        frame:SetPoint("LEFT", previousEntry.GetFrame(), "LEFT", 0, -22);
    else
        frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10, 0);
    end
    local isShown = true;

    local function updateFrame()
        print('updateFrame');
        frame.PlayerName:SetText(playerName);
        print('setting texture: ' .. rollTextures[rollId]);
        frame.RollTexture:SetTexture(rollTextures[rollId]);
        frame:Show();
        isShown = true;
    end;

    updateFrame();
    return {
        IsShown = function () return isShown; end,    
        PlayerName = function () 
            if (not isShown) then return nil; end;
            return playerName; 
        end,
        SetRoll = function (r) 
            rollId = r; 
            updateFrame();
        end,
        Update = function (player, r) 
            rollId = r;
            playerName = player;
            updateFrame();
        end,
        Hide = function () isShown = false; frame:Hide(); end,
        GetFrame = function () return frame; end,
    };
end;

-- closure for each item being looted
LootItemEntryFactory = function (e, previousEntry)

    local isShown = true;
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
        GetItemInfo(e);
    local playerFrames = {};
    local entryContainer = LootMFrames['LootMLootFrame'].ScrollFrame.ItemEntryContainer;
    local frame = CreateFrame('Button', nil, entryContainer, 'ItemEntryDetailsTemplate');
    if (previousEntry) then
        frame:SetPoint("LEFT", previousEntry.GetFrame(), "LEFT", 0, -148);
    else
        frame:SetPoint("TOPLEFT", entryContainer, "TOPLEFT", 10, 0);
    end
    
    local rollButtonClickHandler = function(self)
        LootMComms.Roll(self:GetID(), itemLink);
    end;

    frame.needButton:SetScript('OnClick', rollButtonClickHandler);
    frame.greedButton:SetScript('OnClick', rollButtonClickHandler);
    frame.passButton:SetScript('OnClick', rollButtonClickHandler);

    local function populateFrame()
        frame.ItemName:SetText(itemLink);
        frame.ItemTexture:SetTexture(itemTexture);
        -- TODO: disable need button when not usable;
        frame:Show();
    end;

    populateFrame();

    return {
        GetItemLink = function () return itemLink; end,
        IsShown = function () return isShown; end,
        Show = function (e) 
            itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
                GetItemInfo(e);
            populateFrame();
            isShown = true; 
        end,
        Hide = function () 
            frame:Hide();
            for k,v in pairs(playerFrames) do v.Hide(); end;
            isShown = false; 
        end,
        GetFrame = function () return frame; end,
        SetPlayerRoll = function (player, rollId)
            local previousEntry;
            for k,v in pairs(playerFrames) do
                if (v.PlayerName() == player) then
                    v.SetRoll(rollId);
                    return;
                elseif (not v.IsShown()) then
                    v.Update(player, rollId);
                    return;
                end
                previousEntry = v;
            end
            table.insert(playerFrames, playerFrameFactory(frame, previousEntry, player, rollId));
            print('add roll ' .. rollId .. ' for ' .. player .. ' on item ' .. itemLink);

        end,
    };
end

function LootMEvents.LootMLootFrame_OnLoad()
    -- the main collection of loot items
    LootMItemEntries = (function () 
        local itemEntries = {};
        local frame = LootMFrames['LootMLootFrame'];
        return {
            Hide = function () 
                for k,v in pairs(itemEntries) do
                    v.Hide();
                end
                frame:Hide();
            end,
            Show = function ()
                frame:Show();
            end,
            ShowItem = function (itemLink)
                local lastEntry;
                for k,v in pairs(itemEntries) do
                    if (not v.IsShown()) then
                        v.Show(itemLink);
                        return;
                    end
                    lastEntry = v;
                end
                table.insert(itemEntries, LootItemEntryFactory(itemLink, lastEntry));
            end,
            SetPlayerRoll = function (itemLink, player, rollId)
                for k,v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.SetPlayerRoll(player, rollId);
                    end
                end
            end,
        };
    end)();

end