local defaultStatWeights = 
{
    ITEM_MOD_STAMINA_SHORT=1,
    
    ITEM_MOD_INTELLECT_SHORT=1,
    ITEM_MOD_AGILITY_SHORT=1,
    ITEM_MOD_STRENGTH_SHORT=1,

    ITEM_MOD_CRIT_RATING_SHORT=1,
    ITEM_MOD_HASTE_RATING_SHORT=1,
    ITEM_MOD_MASTERY_RATING_SHORT=1,
    ITEM_MOD_VERSATILITY=1,
    ITEM_MOD_CR_MULTISTRIKE_SHORT=1,

    ITEM_MOD_SPIRIT_SHORT=1,
    RESISTANCE0_NAME=1, -- Armor
    
    ITEM_MOD_ATTACK_POWER_SHORT=1,
    ITEM_MOD_SPELL_POWER_SHORT=1,

    EMPTY_SOCKET_PRISMATIC=50, -- SOCKET BONUS
    ITEM_MOD_CR_STURDINESS_SHORT=.5, -- INDISTRUCTABLE ?
    ITEM_MOD_CR_SPEED_SHORT=.5, -- SPEED
    ITEM_MODE_CR_LIFESTEAL_SHORT=.5, --LEETCH
};

local primaryStats = {
    "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_STRENGTH_SHORT",
}

local secondaryStats = {
    "ITEM_MOD_CRIT_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    "ITEM_MOD_VERSATILITY",
    "ITEM_MOD_CR_MULTISTRIKE_SHORT",
};

local terciaryStats = {
    "ITEM_MOD_CR_STURDINESS_SHORT=1",
    "ITEM_MOD_CR_SPEED_SHORT",
    "ITEM_MODE_CR_LIFESTEAL_SHORT",
};

local socketStatBudgt = 50;

LootMStatWeights = {};

LootM.GetPlayerStatWeights = function () 
    local specid = GetLootSpecialization();
    if (not LootMStatWeights[specid]) then
        LootMStatWeights[specid] = defaultStatWeights;
    end
    return LootMStatWeights[specid];
end

LootM.SetPlayerStatWeights = function(weightsTable)
    local specid = GetLootSpecialization();
    -- only 1 primary stat gets saved (the others are zeroed)
    local highPrimaryStat, primaryStatName;
    for i,k in pairs(primaryStats) do
        if (not highPrimaryStat or weightsTable[k] > highPrimaryStat) then
            highPrimaryStat = weightsTable[k];
            primaryStatName = k;
        end
    end
    for i,k in pairs(primaryStats) do
        if (k ~= primaryStatName) then
            weightsTable[k] = 0;
        end
    end
    -- highest secondary is the socket bonus stat * socket stat budget
    -- terciary stats are half of the lowest secondary stats
    local highSecondary, lowSecondary;
    for i,k in pairs(secondaryStats) do
        if (not highSecondary or weightsTable[k] > highSecondary) then
            highSecondary = weightsTable[k];
        end
        if (not lowSecondary or weightsTable[k] < lowSecondary) then
            lowSecondary = weightsTable[k];
        end
    end
    weightsTable['EMPTY_SOCKET_PRISMATIC'] = (highSecondary * socketStatBudgt);
    for i,k in pairs(terciaryStats) do
        weightsTable[k] = (lowSecondary / 2);
    end

    LootMStatWeights[specid] = weightsTable;
end


function LootMEvents.LootMStatWeightEditor_OnLoad()
    local frame = LootMFrames['LootMStatWeightEditor'];
    frame:Hide();

    local statFrames = {};
    
    local function loadWeights()
        local weights = LootM.GetPlayerStatWeights();
        for k,v in pairs(weights) do
            local x = statFrames[k];
            if (x) then
                x.Value:SetText(v);
            end
        end
        local specName = select(2, GetSpecializationInfoByID(GetLootSpecialization()));
        frame.SpecializationName:SetText(specName);
    end

    local function saveWeights()
        local weights = LootM.GetPlayerStatWeights();
        for k,v in pairs(weights) do
            local x = statFrames[k];
            if (x) then
                weights[k] = x.Value:GetNumber();
            end
        end
        LootM.SetPlayerStatWeights(weights);
        loadWeights();
    end

    local index =1;
    for k,v in pairs({
    "ITEM_MOD_STAMINA_SHORT",
    "ITEM_MOD_INTELLECT_SHORT",
    "ITEM_MOD_AGILITY_SHORT",
    "ITEM_MOD_STRENGTH_SHORT",
    "ITEM_MOD_CRIT_RATING_SHORT",
    "ITEM_MOD_HASTE_RATING_SHORT",
    "ITEM_MOD_MASTERY_RATING_SHORT",
    "ITEM_MOD_VERSATILITY",
    "ITEM_MOD_CR_MULTISTRIKE_SHORT",
    "ITEM_MOD_SPIRIT_SHORT",
    "RESISTANCE0_NAME",
    "ITEM_MOD_ATTACK_POWER_SHORT",
    "ITEM_MOD_SPELL_POWER_SHORT",
    }) do

        local x = CreateFrame('Frame', nil, frame, 'StatEditor');
        x:SetPoint('TOPLEFT', frame, 'TOPLEFT', 10, -(index * 30));
        x.StatName = v;
        x.Label:SetText(_G[v]);
        x.Value.SaveWeights = saveWeights;
        statFrames[v] = x;
        index = index +1;
    end

    LootM.UpdateConfig = function () 
        if (frame:IsShown()) then
            loadWeights();
        end
    end
    LootM.ShowConfig = function ()
        loadWeights();
        frame:Show();
    end
end