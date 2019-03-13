local addon, ns = ...
local cargBags = ns.cargBags

local cbNeav = cargBags:NewImplementation("Neav")
cbNeav:RegisterBlizzard()

function cbNeav:UpdateBags()
    for i = -3, 11 do
        cbNeav:UpdateBag(i)
    end
end

local L = cBneavL
cB_Filters = {}
cB_KnownItems = cB_KnownItems or {}
cBneav_CatInfo = {}
cB_ItemClass = {}

cB_existsBankBag = {
    Armor = true,
    Gem = true,
    Quest = true,
    TradeGoods = true,
    Consumables = true,
    BattlePet = true,
    Fishing = true
}

cB_filterEnabled = {
    Armor = true,
    Gem = true,
    Quest = true,
    TradeGoods = true,
    Consumables = true,
    Keyring = true,
    Junk = true,
    Stuff = true,
    ItemSets = true,
    BattlePet = true,
    Fishing = true
}

--------------------
--Basic filters
--------------------
cB_Filters.fBags = function(item)
    return item.bagID >= 0 and item.bagID <= 4
end

cB_Filters.fBank = function(item)
    return item.bagID == -1 or item.bagID >= 5 and item.bagID <= 11
end

cB_Filters.fBankReagent = function(item)
    return item.bagID == -3
end

cB_Filters.fBankFilter = function()
    return cBneavCfg.FilterBank
end

cB_Filters.fHideEmpty = function(item)
    if cBneavCfg.CompressEmpty then
        return item.link ~= nil
    else
        return true
    end
end

-- General Classification (cached)
cB_Filters.fItemClass = function(item, container)
    if ( not item.id ) then
        return false
    end

    if ( not cB_ItemClass[item.id] ) then
        cbNeav:ClassifyItem(item)
    end

    local class = cB_ItemClass[item.id]
    local isBankBag = item.bagID == -1 or (item.bagID >= 5 and item.bagID <= 11)

    if ( isBankBag ) then
        local bagExists = cB_existsBankBag[class]
        local isFiltered = cB_filterEnabled[class]

        if ( cBneavCfg.FilterBank and bagExists and isFiltered ) then
            bag = "Bank"..class
        else
            bag = "Bank"
        end
    else
        local isFiltered = cB_filterEnabled[class]

        if ( class and class ~= "NoClass" and isFiltered ) then
            bag = class
        else
            bag = "Bag"
        end
    end

    return bag == container
end

local function CanGoInBag(itemID, bagType)
    local itemFamily = GetItemFamily(itemID) or 0

    if ( itemFamily == 67108872 ) then
        return false
    end

    return bit.band(itemFamily, bagType) > 0
end

local classTable = {
    [2] = "Armor",
    [3] = "Gem",
    [4] = "Armor",
    [5] = "Quest",
    [7] = "TradeGoods",
    [8] = "TradeGoods",
    [9] = "TradeGoods",
    [12] = "Quest",
    [17] = "BattlePet",
}

function cbNeav:ClassifyItem(item)
    local customBag = cBneav_CatInfo[item.id]
    if ( customBag ) then
        cB_ItemClass[item.id] = customBag
        return true
    end

    if ( item.quality == 0 ) then
        cB_ItemClass[item.id] = "Junk"
        return true
    end

    if ( item.classID ) then
        local itemType = classTable[item.classID]

        if ( itemType ) then
            cB_ItemClass[item.id] = itemType
            return true
        elseif ( CanGoInBag(item.id, 0x8000) ) then
            cB_ItemClass[item.id] = "Fishing"
            return true
        elseif ( item.classID == 0 ) then
            cB_ItemClass[item.id] = "Consumables"
            return true
        elseif ( item.classID == 15 and item.subclassID == 2 ) then
            cB_ItemClass[item.id] = "BattlePet"
            return true
        end
    end

    cB_ItemClass[item.id] = "NoClass"
end

-- New Items filter
cB_Filters.fNewItems = function(item)
    if ( not cBneavCfg.NewItems ) then
        return false
    end

    if ( item.bagID < 0 or item.bagID > 4 ) then
        return false
    end

    if ( not item.link ) then
        return false
    end

    if ( not cB_KnownItems[item.id] ) then
        return true
    else
        return false
    end

    -- return GetItemCount(item.id) > cB_KnownItems[item.id]
end

-- Item Set filter
cB_Filters.fItemSets = function(item)
    if ( not cB_filterEnabled["ItemSets"] ) then
        return false
    end

    if ( not item.link ) then
        return false
    end

    if ( not cargBags.itemKeys["setID"](item) ) then
        return false
    end

    return true
end
