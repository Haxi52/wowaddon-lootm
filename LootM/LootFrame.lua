
local rollTextures = {
    ['0'] = 'Interface\\Buttons\\UI-GroupLoot-Pass-Up',
    ['1'] = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up',
    ['2'] = 'Interface\\Buttons\\UI-GroupLoot-Coin-Up',
};

local LootItemEntryFactory;
LootMItemEntries = {};

-- closure of player frame (each player listed under the loot item)
local playerFrameFactory = function (parent, index, playerName, rollId, itemsTable)
    local indexOffset = 22;
    local frame = CreateFrame('Button', nil, parent, 'PlayerRollDetail');
    local isShown = true;

    local function setAnchor()
        frame:SetPoint("TOPLEFT", parent.ItemDetails, "BOTTOMLEFT", 10, -((index - 1) * indexOffset));
    end;

    local function setItemFrame(itemId, button)
        if (itemId) then
            local _, itemLink, _, itemLevel, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemId);
            button:SetNormalTexture(itemTexture);
            button.ItemLink = itemLink;
            button:Show();
        else
            button:Hide();
        end
    end

    local function updateFrame()
        frame.PlayerName:SetText(playerName);
        frame.RollTexture:SetTexture(rollTextures[rollId]);
        
        setItemFrame(itemsTable[1], frame.EquippedItem1);
        setItemFrame(itemsTable[2], frame.EquippedItem2);
        
        frame:Show();
        isShown = true;
    end;


    setAnchor();
    updateFrame();
    return {
        IsShown = function () return isShown; end,    
        PlayerName = function () 
            if (not isShown) then return nil; end;
            return playerName; 
        end,
        SetIndex = function (i)
            index = i;
            setAnchor();
        end,
        SetRoll = function (r, i) 
            rollId = r; 
            itemsTable = i;
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
    local defaultFrameHeight = 48;
    local isShown = true;
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
        GetItemInfo(e);
    local playerFrames = {};
    local entryContainer = LootMFrames['LootMLootFrame'].ScrollFrame.ItemEntryContainer;
    local frame = CreateFrame('Button', nil, entryContainer, 'ItemEntryDetailsTemplate');
    if (previousEntry) then
        frame:SetPoint("TOPLEFT", previousEntry.GetFrame(), "BOTTOMLEFT");
    else
        frame:SetPoint("TOPLEFT", entryContainer, "TOPLEFT", 10, 0);
    end
    
    local rollButtonClickHandler = function(self)
        LootMComms.Roll(self:GetID(), itemLink, LootMItemEvaluator.GetPlayerItemDetails(itemLink));
    end;

    frame.ItemDetails.needButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.greedButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.passButton:SetScript('OnClick', rollButtonClickHandler);

    local function populateFrame()
        frame.ItemDetails.ItemName:SetText(itemLink);
        frame.ItemDetails.ItemTexture:SetTexture(itemTexture);
        frame.ItemDetails.ItemLink = itemLink;
        frame.ItemDetails.ItemLevel:SetText('('..itemLevel..')');
        local thisItemType, thisItemSubType;
        if (itemSubType == 'Miscellaneous') then
            thisItemType = _G[itemEquipLocation];
        else
            thisItemType = itemSubType;
            thisItemSubType = _G[itemEquipLocation];
        end
        if (thisItemType) then
            frame.ItemDetails.ItemType:SetText(thisItemType);
        else
            frame.ItemDetails.ItemType:SetText('');
        end
        if (thisItemSubType) then
            frame.ItemDetails.ItemSubType:SetText(thisItemSubType);
        else
            frame.ItemDetails.ItemSubType:SetText('');
        end
        
        -- TODO: disable need button when not usable;
        frame:Show();
    end;

    populateFrame();

    local function updateHeight()
        local playerCount = 0;
        for k,v in pairs(playerFrames) do 
            if (v.IsShown()) then 
                playerCount = playerCount +1;
            end
        end;
        frame:SetHeight((playerCount * 22) + defaultFrameHeight);
    end;

    return {
        GetItemLink = function () return itemLink; end,
        IsShown = function () return isShown; end,
        Show = function (e) 
            itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
                GetItemInfo(e);
            populateFrame();
            updateHeight();
            isShown = true; 
        end,
        Hide = function () 
            frame:Hide();
            for k,v in pairs(playerFrames) do v.Hide(); end;
            isShown = false; 
        end,
        GetFrame = function () return frame; end,
        SetPlayerRoll = function (player, rollId, itemsTable)
            local index = 1;
            for k,v in pairs(playerFrames) do
                if (v.PlayerName() == player) then
                    v.SetRoll(rollId, itemsTable);
                    return;
                elseif (not v.IsShown()) then
                    v.Update(player, rollId);
                    return;
                end
                index = index +1;
            end
            table.insert(playerFrames, playerFrameFactory(frame, index, player, rollId, itemsTable));
            updateHeight();
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
            SetPlayerRoll = function (itemLink, player, rollId, itemsTable)
                for k,v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.SetPlayerRoll(player, rollId, itemsTable);
                    end
                end
            end,
            IsNewLoot = function (lootTable)
                for k,v in pairs(lootTable) do
                    local newLoot = true;
                    for l,i in pairs(itemEntries) do
                        if (v == i.GetItemLink()) then
                            newLoot = false;
                            break;
                        end
                    end
                    if (newLoot) then return true; end
                end;
                return false;
            end,
        };
    end)();

end