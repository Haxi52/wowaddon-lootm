local maxRollChances = 2;
local maxPlayerRollShown = 5;

local rollTextures = {
    ['0'] = 'Interface\\Buttons\\UI-GroupLoot-Pass-Up',
    ['1'] = 'Interface\\Buttons\\UI-GroupLoot-Dice-Up',
    ['2'] = 'Interface\\Buttons\\UI-GroupLoot-Coin-Up',
    ['awarded'] = 'Interface\\RAIDFRAME\\ReadyCheck-Ready',
};

local roleCoords = {
    ['TANK'] = { 0, 0.3125, 0.3125, 0.625 },
    ['HEALER'] = { 0.3125, 0.625, 0, 0.3125 },
    ['DAMAGER'] = { 0.3125, 0.625, 0.3125, 0.625 },
    ['other'] = { 0, 0.3125, 0, 0.3125 },
};

local LootItemEntryFactory;
LootMItemEntries = { };

-- closure of player frame (each player listed under the loot item)
local playerFrameFactory = function(parent, index, playerName, playerRole, rollId, itemsTable, improvementRating)
    debug('playerFrameFactory');
    local indexOffset = 22;
    local frame = CreateFrame('Button', nil, parent, 'PlayerRollDetail');
    local isShown = false;
    local enabled = true;
    local equippedItemLevel = 1000;
    local onClickCallback;

    frame:SetScript("OnClick", function()
        onClickCallback(playerName);
    end );

    local function setAnchor()
        if (index > maxPlayerRollShown or not isShown or not enabled) then
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
        frame.ImprovementRating:SetText('[' .. improvementRating .. ']');
        frame.RoleTexture:SetTexCoord(unpack((roleCoords[playerRole] or roleCoords['other'])));
        equippedItemLevel = 1000;
        setItemFrame(itemsTable[1], frame.EquippedItem1);
        setItemFrame(itemsTable[2], frame.EquippedItem2);

    end;


    updateFrame();
    setAnchor();

    return {
        IsShown = function() return isShown and enabled; end,
        IsEnabled = function() return enabled; end,
        PlayerName = function() return playerName; end,
        GetRoll = function() return rollId; end,
        GetSortOrder = function()
            if (not isShown) then return nil; end
            local r = tonumber(rollId);
            if (r == 0) then r = 4; end
            -- force passes to show at the end
            return(r * 1000) + equippedItemLevel;
        end,
        SetIndex = function(i)
            debug('SetIndex');
            index = i;
            setAnchor();
        end,
        SetRoll = function(rollid)
            debug('SetRoll');
            rollId = rollid;
            updateFrame();
        end,
        SetInfo = function(playername, playerrole, rollid, itemstable, improvementrating, i)
            debug('Update');
            playerName = playername;
            rollId = rollid;
            playerRole = playerrole;
            itemsTable = itemstable;
            improvementRating = improvementrating;
            index = i;
            enabled = true;
            updateFrame();
            setAnchor();
        end,
        Show = function()
            isShown = true;
        end,
        Hide = function()
            isShown = false;
            enabled = false;
            playerName = nil;
            rollId = nil;
            frame:Hide();
        end,
        GetFrame = function() return frame; end,
        OnClick = function(callback)
            onClickCallback = callback;
        end,
        SetAwarded = function()
            frame.RollTexture:SetTexture(rollTextures['awarded']);
        end,
    };
end;

-- closure for each item being looted
LootItemEntryFactory = function(e, previousEntry, playerDetails)
    debug('LootItemEntryFactory');
    local defaultFrameHeight = 52;
    local PlayerDetails = playerDetails;
    local isShown = true;
    local hasRolled = false;
    local rollChances = maxRollChances;
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
    GetItemInfo(e);
    local playerFrames = { };
    local entryContainer = LootMFrames['LootMLootFrame'].ScrollFrame.ItemEntryContainer;
    local frame = CreateFrame('Button', nil, entryContainer, 'ItemEntryDetailsTemplate');
    local rollButtons = {
        frame.ItemDetails.needButton,
        frame.ItemDetails.greedButton,
        frame.ItemDetails.passButton
    };
    if (previousEntry) then
        frame:SetPoint("TOPLEFT", previousEntry.GetFrame(), "BOTTOMLEFT");
    else
        frame:SetPoint("TOPLEFT", entryContainer, "TOPLEFT", 10, 0);
    end

    local function ForEachRollButton(f)
        for k, button in pairs(rollButtons) do f(button) end;
    end
    local turnOffRollButtons = function()
        ForEachRollButton( function(b)
            b:GetNormalTexture():SetDesaturated(true);
            b:GetHighlightTexture():SetDesaturated(true);
            b:GetPushedTexture():SetDesaturated(true);
            b:Disable();
        end );
    end

    local turnOnRollButtons = function()
        ForEachRollButton( function(b)
            b:Enable();
            b:GetNormalTexture():SetDesaturated(false);
            b:GetHighlightTexture():SetDesaturated(false);
            b:GetPushedTexture():SetDesaturated(false);
            b.selectedTexture:Hide();
        end );
    end

    local rollButtonClickHandler = function(self)
        PlaySound("igMainMenuOptionCheckBoxOn");
        LootMComms.Roll(self:GetID(), itemLink, PlayerDetails);
        ForEachRollButton( function(b)
            if (self == b) then
                b.selectedTexture:Show();
            else
                b.selectedTexture:Hide();
            end
        end );
        rollChances = rollChances - 1;
        if (rollChances <= 0) then
            turnOffRollButtons();
        end;
        hasRolled = true;
        for k, v in pairs(playerFrames) do
            if (v.IsEnabled()) then v.Show(); end;
        end;
    end;

    local updateRollCount = function()
        local rollCount = { };
        for k, v in pairs(playerFrames) do
            local roll = v.GetRoll();
            if (roll) then
                rollCount[roll] =(rollCount[roll] or 0) + 1;
            end
        end
        frame.ItemDetails.needButton.Label:SetText(rollCount['1']);
        frame.ItemDetails.greedButton.Label:SetText(rollCount['2']);
        frame.ItemDetails.passButton.Label:SetText(rollCount['0']);
    end

    frame.ItemDetails.needButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.greedButton:SetScript('OnClick', rollButtonClickHandler);
    frame.ItemDetails.passButton:SetScript('OnClick', rollButtonClickHandler);

    local function populateFrame()
        debug('populateFrame');
        frame.ItemDetails.ItemName:SetText(itemLink);
        frame.ItemDetails.ItemTexture:SetTexture(itemTexture);
        frame.ItemDetails.ItemLink = itemLink;
        frame.ItemDetails.ItemLevel:SetText(itemLevel);
        frame.ItemDetails.ImprovementRating:SetText(PlayerDetails.ImprovementRaiting);

        local thisItemType, thisItemSubType;
        local tokenType = LootMItemEvaluator.GetTokenType(itemLink);
        if (tokenType) then
            thisItemType = tokenType;
        elseif (itemSubType == 'Miscellaneous') then
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

        updateRollCount();
        -- TODO: disable need button when not usable;
        frame:Show();
    end;

    populateFrame();

    local function updateHeight()
        debug('LootItemEntryFactory:updateHeight');
        local playerCount = 0;
        for k, v in pairs(playerFrames) do
            if (v.IsShown()) then
                playerCount = playerCount + 1;
            end
        end;
        playerCount = math.min(playerCount, maxPlayerRollShown);
        frame:SetHeight((playerCount * 22) + defaultFrameHeight);
    end;

    local function sortPlayerTable()
        debug('sortPlayerTable');
        local index = 1;
        for
            k, v in spairs(playerFrames, function(t, a, b)
                local sortOrdera = t[a].GetSortOrder();
                local sortOrderb = t[b].GetSortOrder();
                if (not sortOrdera) then return false; end
                if (not sortOrderb) then return true; end
                -- a has a value, b does not
                return sortOrdera < sortOrderb;
            end )
        do
            v.SetIndex(index);
            index = index + 1;
        end
    end;

    local function updateAll()
        sortPlayerTable();
        updateHeight();
        updateRollCount();
    end

    local function assignLootClicker(playername)
        LootM.AwardLoot(playername, itemLink);
    end

    return {
        GetItemLink = function() return itemLink; end,
        IsShown = function() return isShown; end,
        Show = function(e, playerDetails)
            debug('LootItemEntryFactory:Show');
            itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
            GetItemInfo(e);
            PlayerDetails = playerDetails;
            rollChances = maxRollChances;
            turnOnRollButtons();
            populateFrame();
            updateHeight();
            isShown = true;
            hasRolled = false;
        end,
        Hide = function()
            debug('LootItemEntryFactory:Hide');
            frame:Hide();
            for k, v in pairs(playerFrames) do v.Hide(); end;
            isShown = false;
        end,
        GetFrame = function() return frame; end,
        SetPlayerRoll = function(player, role, rollId, itemsTable, improvementRating)
            debug('LootItemEntryFactory:SetPlayerRoll');
            local index = 0;
            for k, v in pairs(playerFrames) do
                index = index + 1;
                if (v.PlayerName() == player) then
                    v.SetRoll(rollId);
                    if (hasRolled) then v.Show(); end;
                    updateAll();
                    return;
                elseif (not v.IsShown()) then
                    v.SetInfo(player, role, rollId, itemsTable, improvementRating, index);
                    if (hasRolled) then v.Show(); end;
                    updateAll();
                    return;
                end
            end
            local newPlayerFrame = playerFrameFactory(frame, index, player, role, rollId, itemsTable, improvementRating);
            table.insert(playerFrames, newPlayerFrame);
            newPlayerFrame.OnClick(assignLootClicker);
            if (hasRolled) then newPlayerFrame.Show(); end;
            updateAll();
        end,
        AwardItem = function(player)
            debug('LootItemEntryFactory:AwardItem');
            turnOffRollButtons();
            for k, v in pairs(playerFrames) do
                if (v.PlayerName() == player) then
                    v.SetAwarded();
                    return;
                end
            end
        end,
    };
end

function LootMEvents.LootMLootFrame_OnLoad()
    -- the main collection of loot items
    LootMItemEntries =( function()
        debug('LootItemEntryFactory:LootMItemEntries');
        local itemEntries = { };
        local frame = LootMFrames['LootMLootFrame'];
        return {
            Hide = function()
                for k, v in pairs(itemEntries) do
                    v.Hide();
                end
                frame:Hide();
            end,
            Show = function()
                frame:Show();
            end,
            ShowItem = function(itemLink, playerDetails)
                debug('LootMItemEntries:ShowItem');
                local lastEntry;
                for k, v in pairs(itemEntries) do
                    if (not v.IsShown()) then
                        v.Show(itemLink, playerDetails);
                        return;
                    end
                    lastEntry = v;
                end
                table.insert(itemEntries, LootItemEntryFactory(itemLink, lastEntry, playerDetails));
            end,
            GetItems = function()
                debug('LootMItemEntries:GetItems');
                local output = { };
                for k, v in pairs(itemEntries) do
                    table.insert(output, v.GetItemLink());
                end
                return output;
            end,
            SetPlayerRoll = function(itemLink, player, role, rollId, itemsTable, improvementRating)
                debug('LootMItemEntries:SetPlayerRoll');
                for k, v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.SetPlayerRoll(player, role, rollId, itemsTable, improvementRating);
                        return;
                    end
                end
                debug('could not find item to set roll.');
            end,
            IsNewLoot = function(lootTable)
                debug('LootMItemEntries:IsNewLoot');
                if (not lootTable) then return false; end
                for k, v in pairs(lootTable) do
                    local newLoot = true;
                    for l, i in pairs(itemEntries) do
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
            AwardItem = function(itemLink, player)
                for k, v in pairs(itemEntries) do
                    if (v.GetItemLink() == itemLink) then
                        v.AwardItem(player);
                    end
                end
            end
        };
    end )();
end