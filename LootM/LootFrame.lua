local maxRollChances = 2;
local maxPlayerRollShown = 5;

local rollTextures = {
    ['0'] = 'Interface\\Buttons\\UI-GroupLoot-Pass-Up',
    ['1'] = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up',
    ['2'] = 'Interface\\Buttons\\UI-GroupLoot-Coin-Up',
    ['awarded'] = 'Interface\\RAIDFRAME\\ReadyCheck-Ready',
};

local roleCoords = {
    ['TANK'] =   {0,       0.3125,  0.3125, 0.625},
    ['HEALER'] = {0.3125,  0.625,   0,      0.3125},
    ['DAMAGER'] ={0.3125,  0.625,   0.3125, 0.625},
    ['other'] =  {0,       0.3125,  0,      0.3125},
};

local LootItemEntryFactory;
LootMItemEntries = {};

-- closure of player frame (each player listed under the loot item)
local playerFrameFactory = function (parent, index, playerName, role, rollId, itemsTable, improvementRating)
    local indexOffset = 22;
    local frame = CreateFrame('Button', nil, parent, 'PlayerRollDetail');
    local isShown = true;
    local equippedItemLevel = 1000;
    local onClickCallback;

    frame:SetScript("OnClick", function ()
        onClickCallback(playerName);
    end);

    local function setAnchor()
        if (index > maxPlayerRollShown) then 
            frame:Hide(); 
        elseif (isShown) then
            frame:ClearAllPoints();
            frame:SetPoint("TOPLEFT", parent.ItemDetails, "BOTTOMLEFT", 10, -((index - 1) * indexOffset));
            frame:Show(); 
        end
    end;

    local function setItemFrame(itemId, button)
        if (itemId) then
            local _, itemLink, _, itemLevel, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemId);
            button:SetNormalTexture(itemTexture);
            button.ItemLink = itemLink;
            button.ItemLevel:SetText(itemLevel);
            button:Show();
            equippedItemLevel = math.min(equippedItemLevel, itemLevel);
        else
            button:Hide();
        end
    end

    local function updateFrame()
        frame.PlayerName:SetText(playerName);
        frame.RollTexture:SetTexture(rollTextures[rollId]);
        frame.ImprovementRating:SetText('['..improvementRating..']');
        frame.RoleTexture:SetTexCoord(unpack((roleCoords[role] or roleCoords['other'])));
        equippedItemLevel = 1000;
        setItemFrame(itemsTable[1], frame.EquippedItem1);
        setItemFrame(itemsTable[2], frame.EquippedItem2);
        
        if (index < maxPlayerRollShown) then frame:Show(); end
        isShown = true;
    end;


    setAnchor();
    updateFrame();
    return {
        IsShown = function () return isShown; end,    
        GetRoll = function () return rollId; end,
        GetItemLevel = function () return equippedItemLevel; end,
        PlayerName = function () 
            if (not isShown) then return nil; end;
            return playerName; 
        end,
        SetIndex = function (i)
            index = i;
            setAnchor();
        end,
        -- role, rollId, item table, improvement rating
        SetRoll = function (s, r, i, imp) 
            role = s;
            rollId = r; 
            itemsTable = i;
            improvementRating = imp;
            updateFrame();
        end,
        -- player name, role, rollId, item table, improvement rating
        Update = function (player, s, r, i, imp) 
            rollId = r;
            playerName = player;
            role = s;
            itemsTable = i;
            improvementRating = imp;
            updateFrame();
        end,
        Hide = function () isShown = false; frame:Hide(); end,
        GetFrame = function () return frame; end,
        OnClick = function(callback)
            onClickCallback = callback;
        end,
        SetAwarded = function ()
            frame.RollTexture:SetTexture(rollTextures['awarded']);
        end,
    };
end;

-- closure for each item being looted
LootItemEntryFactory = function (e, previousEntry, playerDetails)
    local defaultFrameHeight = 52;
    local PlayerDetails = playerDetails;
    local isShown = true;
    local rollChances = maxRollChances;
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
        GetItemInfo(e);
    local playerFrames = {};
    local entryContainer = LootMFrames['LootMLootFrame'].ScrollFrame.ItemEntryContainer;
    local frame = CreateFrame('Button', nil, entryContainer, 'ItemEntryDetailsTemplate');
    local rollButtons = { frame.ItemDetails.needButton, frame.ItemDetails.greedButton, frame.ItemDetails.passButton };
    if (previousEntry) then
        frame:SetPoint("TOPLEFT", previousEntry.GetFrame(), "BOTTOMLEFT");
    else
        frame:SetPoint("TOPLEFT", entryContainer, "TOPLEFT", 10, 0);
    end
    
    local function ForEachRollButton(f) 
        for k,button in pairs(rollButtons) do f(button) end;
    end
    local turnOffRollButtons = function () 
        ForEachRollButton(function (b) 
            b:GetNormalTexture():SetDesaturated(true);
            b:GetHighlightTexture():SetDesaturated(true);
            b:GetPushedTexture():SetDesaturated(true);
            b:Disable();
        end);
    end

    local turnOnRollButtons = function ()
        ForEachRollButton(function (b) 
            b:Enable();
            b:GetNormalTexture():SetDesaturated(false);
            b:GetHighlightTexture():SetDesaturated(false);
            b:GetPushedTexture():SetDesaturated(false);
        end);
    end

    local rollButtonClickHandler = function(self)
        LootMComms.Roll(self:GetID(), itemLink, PlayerDetails);
        rollChances = rollChances -1;
        if (rollChances <= 0) then
            turnOffRollButtons();
        end;
    end;

    frame.ItemDetails.needButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.greedButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.passButton:SetScript('OnClick', rollButtonClickHandler);

    local function populateFrame()
        frame.ItemDetails.ItemName:SetText(itemLink);
        frame.ItemDetails.ItemTexture:SetTexture(itemTexture);
        frame.ItemDetails.ItemLink = itemLink;
        frame.ItemDetails.ItemLevel:SetText(itemLevel);
        frame.ItemDetails.ImprovementRating:SetText(PlayerDetails.ImprovementRaiting);
        local thisItemType, thisItemSubType;
        if (itemSubType == 'Miscellaneous') then
            thisItemType = _G[itemEquipLocation];
        elseif (itemType == 'Weapon') then
            thisItemType = itemSubType;
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
        playerCount = math.min(playerCount, maxPlayerRollShown);
        frame:SetHeight((playerCount * 22) + defaultFrameHeight);
    end;

    local function sortPlayerTable()
        local index =1;
        for k,v in spairs(playerFrames, function (t, a, b)
                if (t[a].GetRoll() == '0') then return true; end
                if (t[a].GetRoll() == t[b].GetRoll()) then
                    return t[a].GetItemLevel() < t[b].GetItemLevel();
                else
                    return t[a].GetRoll() < t[b].GetRoll();
                end
            end) do
            v.SetIndex(index);
            index = index +1;
        end
    end;

    local function assignLootClicker(playername)
        LootM.AwardLoot(playername, itemLink);
    end

    return {
        GetItemLink = function () return itemLink; end,
        IsShown = function () return isShown; end,
        Show = function (e, playerDetails) 
            itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
                GetItemInfo(e);
            PlayerDetails = playerDetails;
            rollChances = maxRollChances;
            turnOnRollButtons();
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
        SetPlayerRoll = function (player, role, rollId, itemsTable, improvementRating)
            local index = 1;
            for k,v in pairs(playerFrames) do
                if (v.PlayerName() == player) then
                    v.SetRoll(role, rollId, itemsTable, improvementRating);
                    sortPlayerTable();
                    updateHeight();
                    return;
                elseif (not v.IsShown()) then
                    v.Update(player, role, rollId, itemsTable, improvementRating);
                    sortPlayerTable();
                    updateHeight();
                    return;
                end
                index = index +1;
            end
            local newPlayerFrame = playerFrameFactory(frame, index, player, role, rollId, itemsTable, improvementRating);
            table.insert(playerFrames, newPlayerFrame);
            newPlayerFrame.OnClick(assignLootClicker);
            sortPlayerTable();
            updateHeight();
        end,
        AwardItem = function (player)
            turnOffRollButtons();
            for k,v in pairs(playerFrames) do
                if (v.PlayerName() == player) then
                    v.SetAwarded();
                    return;
                end
            end
        end,
    };
end

function LootMEvents.LootMLootFrame_OnLoad()
    LootM.Update();
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
            ShowItem = function (itemLink, playerDetails)
                local lastEntry;
                for k,v in pairs(itemEntries) do
                    if (not v.IsShown()) then
                        v.Show(itemLink, playerDetails);
                        return;
                    end
                    lastEntry = v;
                end
                table.insert(itemEntries, LootItemEntryFactory(itemLink, lastEntry, playerDetails));
            end,
            GetItems = function ()
                local output = {};
                for k,v in pairs(itemEntries) do
                    table.insert(output, v.GetItemLink());
                end
                return output;
            end,
            SetPlayerRoll = function (itemLink, player, role, rollId, itemsTable, improvementRating)
                for k,v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.SetPlayerRoll(player, role, rollId,  itemsTable, improvementRating);
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
            -- doesn't award the item, but updates the UI to show an item has been awarded
            AwardItem = function (itemLink, player)
                for k,v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.AwardItem(player);
                    end
                end
            end
        };
    end)();

    StaticPopupDialogs[ConfirmLootAwardDialg] = {
      text = "Are you sure you wish to award %s to %s",
      button1 = ACCEPT,
      button2 = CANCEL,
      OnAccept = function(self, data)
          if (type(data) == 'function') then data(); end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
    };
end