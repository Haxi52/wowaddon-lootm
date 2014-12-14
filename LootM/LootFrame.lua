
local LootItemEntryFactory;
LootMItemEntries = {};

LootItemEntryFactory = function (e, previousEntry)

    local isShown = true;
    local itemName, itemLink, itemRarity, itemLevel, _, itemType, itemSubType, _, itemEquipLocation, itemTexture =
        GetItemInfo(e);
    
    local entryContainer = LootMFrames['LootMLootFrame'].ItemEntryContainer;
    local frame = CreateFrame('Button', nil, entryContainer, 'ItemEntryDetailsTemplate');
    if (previousEntry) then
        frame:SetPoint("LEFT", previousEntry.GetFrame(), "LEFT", 0, -48);
    else
        frame:SetPoint("TOPLEFT", entryContainer, "TOPLEFT", 10, -25);
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
            isShown = false; 
        end,
        GetFrame = function () return frame; end,
        SetPlayerRoll = function (player, rollId)
            print('add roll ' .. rollId .. ' for ' .. player .. ' on item ' .. itemLink);
        end,
    };
end

function LootMEvents.LootMLootFrame_OnLoad()
    
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