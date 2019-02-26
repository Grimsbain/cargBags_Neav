local addon, ns = ...
local cargBags = ns.cargBags

cargBags_Neav = CreateFrame("Frame", "cargBags_Neav", UIParent)
cargBags_Neav:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)
cargBags_Neav:RegisterEvent("ADDON_LOADED")

local cbNeav = cargBags:GetImplementation("Neav")

--Replacement for UIDropDownMenu
do
    local frameHeight = 14
    local defaultWidth = 120
    local frameInset = 16

    local dropdown = cbNeavCatDropDown or CreateFrame("Frame", "cbNeavCatDropDown", UIParent)
    dropdown.ActiveButtons = 0
    dropdown.Buttons = {}

    dropdown:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdown:SetSize(defaultWidth+frameInset, 32)
    dropdown:SetClampedToScreen(true)

    local bgOffset = 3
    dropdown.Background = dropdown:CreateTexture("$parentBackground", "BACKGROUND")
    dropdown.Background:SetColorTexture(0.0, 0.0, 0.0, 0.90)
    dropdown.Background:SetPoint("TOPLEFT", dropdown, bgOffset, -bgOffset)
    dropdown.Background:SetPoint("BOTTOMRIGHT", dropdown, -bgOffset, bgOffset)

    if ( IsAddOnLoaded("!Beautycase") ) then
        dropdown:CreateBeautyBorder(12)
    end

    function dropdown:CreateButton()
        local button = CreateFrame("Button", "$parentDropdown", self)
        button:SetWidth(defaultWidth)
        button:SetHeight(frameHeight)

        local fontString = button:CreateFontString("$parentText")
        fontString:SetJustifyH("LEFT")
        fontString:SetJustifyV("MIDDLE")
        fontString:SetFont(unpack(ns.options.fonts.dropdown))
        fontString:SetPoint("LEFT", button, "LEFT", 0, 0)
        button.Text = fontString

        function button:SetText(text)
            button.Text:SetText(text)
        end

        button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]])

        return button
    end

    function dropdown:AddButton(text, value, func)
        local id = self.ActiveButtons+1
        local button = self.Buttons[id] or self:CreateButton()

        button:SetText(text or "")
        button.value = value
        button.func = func or function() end

        button:SetScript("OnClick", function(self, ...)
            self:func(...)
            self:GetParent():Hide()
        end)

        button:ClearAllPoints()
        if ( id == 1 ) then
            button:SetPoint("TOP", self, "TOP", 0, -(frameInset/2))
        else
            button:SetPoint("TOP", self.Buttons[id-1], "BOTTOM", 0, 0)
        end

        self.Buttons[id] = button
        self.ActiveButtons = id
        self:UpdateSize()
    end

    function dropdown:UpdatePosition(frame, point, relativepoint, ofsX, ofsY)
        point = point or "TOPLEFT"
        relativepoint = relativepoint or "BOTTOMLEFT"
        ofsX = ofsX or 0
        ofsY = ofsY or 0

        self:ClearAllPoints()
        self:SetPoint(point, frame, relativepoint, ofsX, ofsY)
    end

    function dropdown:UpdateSize()
        local maxButtons = self.ActiveButtons
        local maxwidth = defaultWidth

        for i=1, maxButtons do
            local width = self.Buttons[i].Text:GetWidth()
            if ( width > maxwidth ) then
                maxwidth = width
            end
        end

        for i=1, maxButtons do
            self.Buttons[i]:SetWidth(maxwidth)
        end

        local height = maxButtons * frameHeight

        self:SetSize(maxwidth+frameInset, height+frameInset)
    end

    function dropdown:Toggle(frame, point, relativepoint, ofsX, ofsY)
        cbNeav:CatDropDownInit()
        self:UpdatePosition(frame, point, relativepoint, ofsX, ofsY)
        self:Show()
    end

    tinsert(UISpecialFrames, dropdown:GetName())
end

---------------------------------------------
---------------------------------------------
local L = cBneavL
cB_Bags = {}
cB_BagHidden = {}
cB_CustomBags = {}

-- Those are default values only, change them ingame via "/cbneav":
local optDefaults = {
    NewItems = true,
    Restack = true,
    TradeGoods = true,
    Armor = true,
    Gem = true,
    CoolStuff = false,
    Junk = true,
    ItemSets = true,
    Consumables = true,
    Quest = true,
    Fishing = true,
    scale = 1,
    FilterBank = true,
    CompressEmpty = true,
    Unlocked = true,
    SortBags = true,
    SortBank = true,
    BankCustomBags = true,
    SellJunk = true,
}

-- Those are internal settings, don"t touch them at all:
local defaults = {}
local bankOpenState = false

function cbNeav:ShowBags(...)
    local bags = {...}
    for i = 1, #bags do
        local bag = bags[i]
        if ( not cB_BagHidden[bag.name] ) then
            bag:Show()
        end
    end
end

function cbNeav:HideBags(...)
    local bags = {...}
    for i = 1, #bags do
        local bag = bags[i]
        bag:Hide()
    end
end

local function LoadDefaults()
    cBneav = cBneav or {}
    for key, value in pairs(defaults) do
        if ( type(cBneav[key]) == "nil" ) then
            cBneav[k] = value
        end
    end

    cBneavCfg = cBneavCfg or {}
    for key, value in pairs(optDefaults) do
        if ( type(cBneavCfg[key]) == "nil" ) then
            cBneavCfg[key] = value
        end
    end
end

function cargBags_Neav:ADDON_LOADED(event, name)
    if ( name ~= addon ) then
        return
    end

    self:UnregisterEvent(event)

    LoadDefaults()

    cB_filterEnabled["Armor"] = cBneavCfg.Armor
    cB_filterEnabled["Gem"] = cBneavCfg.Gem
    cB_filterEnabled["TradeGoods"] = cBneavCfg.TradeGoods
    cB_filterEnabled["Junk"] = cBneavCfg.Junk
    cB_filterEnabled["ItemSets"] = cBneavCfg.ItemSets
    cB_filterEnabled["Consumables"] = cBneavCfg.Consumables
    cB_filterEnabled["Quest"] = cBneavCfg.Quest
    cB_filterEnabled["Fishing"] = cBneavCfg.Fishing
    cBneav.BankCustomBags = cBneavCfg.BankCustomBags
    cBneav.BagPos = true

    -----------------
    -- Frame Spawns
    -----------------
    local Bag = cbNeav:GetContainerClass()

    -- Bank Bags
    cB_Bags.bankSets        = Bag:New("cBneav_BankSets")

    -- Setup custom bank bags.
    if ( cBneav.BankCustomBags ) then
        for i = 1, #cB_CustomBags do
            local bag = cB_CustomBags[i]
            cB_Bags["Bank"..bag.name] = Bag:New("Bank"..bag.name)
            cB_existsBankBag[bag.name] = true
        end
    end

    -- Setup static bank bags.
    cB_Bags.bankArmor           = Bag:New("cBneav_BankArmor")
    cB_Bags.bankGem             = Bag:New("cBneav_BankGem")
    cB_Bags.bankConsumables     = Bag:New("cBneav_BankCons")
    cB_Bags.bankBattlePet       = Bag:New("cBneav_BankPet")
    cB_Bags.bankQuest           = Bag:New("cBneav_BankQuest")
    cB_Bags.bankTrade           = Bag:New("cBneav_BankTrade")
    cB_Bags.bankFishing         = Bag:New("cBneav_BankFishing")
    cB_Bags.bankReagent         = Bag:New("cBneav_BankReagent")
    cB_Bags.bank                = Bag:New("cBneav_Bank")

    -- Setup filters.
    cB_Bags.bankSets            :SetMultipleFilters(true, cB_Filters.fBank, cB_Filters.fBankFilter, cB_Filters.fItemSets)
    cB_Bags.bankArmor           :SetExtendedFilter(cB_Filters.fItemClass, "BankArmor")
    cB_Bags.bankGem             :SetExtendedFilter(cB_Filters.fItemClass, "BankGem")
    cB_Bags.bankConsumables     :SetExtendedFilter(cB_Filters.fItemClass, "BankConsumables")
    cB_Bags.bankBattlePet       :SetExtendedFilter(cB_Filters.fItemClass, "BankBattlePet")
    cB_Bags.bankQuest           :SetExtendedFilter(cB_Filters.fItemClass, "BankQuest")
    cB_Bags.bankTrade           :SetExtendedFilter(cB_Filters.fItemClass, "BankTradeGoods")
    cB_Bags.bankFishing         :SetExtendedFilter(cB_Filters.fItemClass, "BankFishing")
    cB_Bags.bankReagent         :SetMultipleFilters(true, cB_Filters.fBankReagent, cB_Filters.fHideEmpty)
    cB_Bags.bank                :SetMultipleFilters(true, cB_Filters.fBank, cB_Filters.fHideEmpty)

    -- Setup custom bag filters.
    if ( cBneav.BankCustomBags ) then
        for i=1, #cB_CustomBags do
            local bag = cB_CustomBags[i]
            cB_Bags["Bank"..bag.name]:SetExtendedFilter(cB_Filters.fItemClass, "Bank"..bag.name)
        end
    end

    -- Inventory Bags
    cB_Bags.bagItemSets = Bag:New("cBneav_ItemSets")
    cB_Bags.bagStuff    = Bag:New("cBneav_Stuff")

    -- Setup low priority custom bags.
    for i=1, #cB_CustomBags do
        local bag = cB_CustomBags[i]

        if ( bag.prio > 0 ) then
            cB_Bags[bag.name] = Bag:New(bag.name, { isCustomBag = true } )
            bag.active = true
            cB_filterEnabled[bag.name] = true
        end
    end

    -- Setup junk and new item bags.
    cB_Bags.bagJunk     = Bag:New("cBneav_Junk")
    cB_Bags.bagNew      = Bag:New("cBneav_NewItems")

    -- Setup high priority custom bags.
    for i=1, #cB_CustomBags do
        local bag = cB_CustomBags[i]

        if ( bag.prio <= 0 ) then
            cB_Bags[bag.name] = Bag:New(bag.name, { isCustomBag = true } )
            bag.active = true
            cB_filterEnabled[bag.name] = true
        end
    end

    -- Setup static bags.
    cB_Bags.bagFishing      = Bag:New("cBneav_Fishing")
    cB_Bags.armor           = Bag:New("cBneav_Armor")
    cB_Bags.gem             = Bag:New("cBneav_Gem")
    cB_Bags.quest           = Bag:New("cBneav_Quest")
    cB_Bags.consumables     = Bag:New("cBneav_Consumables")
    cB_Bags.battlepet       = Bag:New("cBneav_BattlePet")
    cB_Bags.tradegoods      = Bag:New("cBneav_TradeGoods")
    cB_Bags.main            = Bag:New("cBneav_Bag")

    -- Setup filters.
    cB_Bags.bagItemSets     :SetFilter(cB_Filters.fItemSets, true)
    cB_Bags.bagStuff        :SetExtendedFilter(cB_Filters.fItemClass, "Stuff")
    cB_Bags.bagJunk         :SetExtendedFilter(cB_Filters.fItemClass, "Junk")
    cB_Bags.bagFishing      :SetExtendedFilter(cB_Filters.fItemClass, "Fishing")
    cB_Bags.bagNew          :SetFilter(cB_Filters.fNewItems, true)
    cB_Bags.armor           :SetExtendedFilter(cB_Filters.fItemClass, "Armor")
    cB_Bags.gem             :SetExtendedFilter(cB_Filters.fItemClass, "Gem")
    cB_Bags.quest           :SetExtendedFilter(cB_Filters.fItemClass, "Quest")
    cB_Bags.consumables     :SetExtendedFilter(cB_Filters.fItemClass, "Consumables")
    cB_Bags.battlepet       :SetExtendedFilter(cB_Filters.fItemClass, "BattlePet")
    cB_Bags.tradegoods      :SetExtendedFilter(cB_Filters.fItemClass, "TradeGoods")
    cB_Bags.main            :SetMultipleFilters(true, cB_Filters.fBags, cB_Filters.fHideEmpty)

    -- Setup custom bag filters.
    for i=1, #cB_CustomBags do
        local bag = cB_CustomBags[i]
        cB_Bags[bag.name]:SetExtendedFilter(cB_Filters.fItemClass, bag.name)
    end

    -- Setup inventory and bank locations.
    cB_Bags.main:SetPoint("BOTTOMRIGHT", -53, 107)
    cB_Bags.bank:SetPoint("TOPLEFT", 20, -20)
    cB_Bags.main:RegisterForDrag("LeftButton")
    cB_Bags.bank:RegisterForDrag("LeftButton")

    cbNeav:CreateAnchors()
    cbNeav:Init()
    cbNeav:ToggleBagPosButtons()
end

function cbNeav:CreateAnchors()
    -----------------------------------------------
    -- Store the anchoring order:
    -- read: "self" is anchored to "parent" in the direction denoted by "direction".
    -----------------------------------------------
    local function CreateAnchorInfo(self, parent, direction)
        self.AnchorTo = parent
        self.AnchorDir = direction

        if ( parent ) then
            if ( not parent.AnchorTargets ) then
                parent.AnchorTargets = {}
            end
            parent.AnchorTargets[self] = true
        end
    end

    -- neccessary if this function is used to update the anchors:
    for name, _ in pairs(cB_Bags) do
        if not ((name == "main") or (name == "bank")) then
            cB_Bags[name]:ClearAllPoints()
        end
        cB_Bags[name].AnchorTo = nil
        cB_Bags[name].AnchorDir = nil
        cB_Bags[name].AnchorTargets = nil
    end

    -- Main Anchors
    CreateAnchorInfo(cB_Bags.main, nil, "Bottom")
    CreateAnchorInfo(cB_Bags.bank, nil, "Bottom")

    -- Bank Anchors
    CreateAnchorInfo(cB_Bags.bankReagent, cB_Bags.bank, "Right")
    CreateAnchorInfo(cB_Bags.bankTrade, cB_Bags.bankReagent, "Bottom")
    CreateAnchorInfo(cB_Bags.bankGem, cB_Bags.bankTrade, "Bottom")

    CreateAnchorInfo(cB_Bags.bankArmor, cB_Bags.bank, "Bottom")
    CreateAnchorInfo(cB_Bags.bankSets, cB_Bags.bankArmor, "Bottom")
    CreateAnchorInfo(cB_Bags.bankConsumables, cB_Bags.bankSets, "Bottom")
    CreateAnchorInfo(cB_Bags.bankFishing, cB_Bags.bankConsumables, "Bottom")
    CreateAnchorInfo(cB_Bags.bankQuest, cB_Bags.bankFishing, "Bottom")
    CreateAnchorInfo(cB_Bags.bankBattlePet, cB_Bags.bankQuest, "Bottom")

    -- Setup bank custom bag Anchors
    if ( cBneav.BankCustomBags ) then
        local ref = { [0] = 0, [1] = 0 }

        for i=1, #cB_CustomBags do
            local bag = cB_CustomBags[i]
            if ( bag.active ) then
                --local column = bag.col
                local column = 1

                if ( ref[column] == 0 ) then
                    ref[column] = (column == 0) and cB_Bags.bankBattlePet or cB_Bags.bankGem
                end
                CreateAnchorInfo(cB_Bags["Bank"..bag.name], ref[column], "Bottom")
                ref[column] = cB_Bags["Bank"..bag.name]
            end
        end
    end

    -- Setup inventory anchors.
    CreateAnchorInfo(cB_Bags.bagItemSets, cB_Bags.main, "Left")
    CreateAnchorInfo(cB_Bags.armor, cB_Bags.bagItemSets, "Top")
    CreateAnchorInfo(cB_Bags.gem, cB_Bags.armor, "Top")
    CreateAnchorInfo(cB_Bags.battlepet, cB_Bags.gem, "Top")
    CreateAnchorInfo(cB_Bags.bagFishing, cB_Bags.battlepet, "Top")
    CreateAnchorInfo(cB_Bags.bagStuff, cB_Bags.bagFishing, "Top")

    CreateAnchorInfo(cB_Bags.tradegoods, cB_Bags.main, "Top")
    CreateAnchorInfo(cB_Bags.consumables, cB_Bags.tradegoods, "Top")
    CreateAnchorInfo(cB_Bags.quest, cB_Bags.consumables, "Top")
    CreateAnchorInfo(cB_Bags.bagJunk, cB_Bags.quest, "Top")
    CreateAnchorInfo(cB_Bags.bagNew, cB_Bags.bagJunk, "Top")

    -- Setup custom bag anchors
    local ref = { [0] = 0, [1] = 0 }
    for i=1, #cB_CustomBags do
        local bag = cB_CustomBags[i]
        if ( bag.active ) then
            local column = bag.col
            if ( ref[column] == 0 ) then
                ref[column] = (column == 0) and cB_Bags.bagStuff or cB_Bags.bagNew
            end
            CreateAnchorInfo(cB_Bags[bag.name], ref[column], "Top")
            ref[column] = cB_Bags[bag.name]
        end
    end

    -- Update Anchors
    for _, bag in pairs(cB_Bags) do
        cbNeav:UpdateAnchors(bag)
    end
end

function cbNeav:UpdateAnchors(self)
    if ( not self.AnchorTargets ) then
        return
    end

    for frame, _ in pairs(self.AnchorTargets) do
        local anchoredTo, anchorDir = frame.AnchorTo, frame.AnchorDir
        if ( anchoredTo ) then
            local isHidden = cB_BagHidden[anchoredTo.name]
            frame:ClearAllPoints()

            if ( not isHidden and anchorDir == "Top" ) then
                frame:SetPoint("BOTTOM", anchoredTo, "TOP", 0, 9)
            elseif ( isHidden and anchorDir == "Top" ) then
                frame:SetPoint("BOTTOM", anchoredTo, "BOTTOM")
            elseif ( not isHidden and anchorDir == "Bottom" ) then
                frame:SetPoint("TOP", anchoredTo, "BOTTOM", 0, -9)
            elseif ( isHidden and anchorDir == "Bottom" ) then
                frame:SetPoint("TOP", anchoredTo, "TOP")
            elseif ( anchorDir == "Left" ) then
                frame:SetPoint("BOTTOMRIGHT", anchoredTo, "BOTTOMLEFT", -9, 0)
            elseif ( anchorDir == "Right" ) then
                frame:SetPoint("TOPLEFT", anchoredTo, "TOPRIGHT", 9, 0)
            end
        end
    end
end

function cbNeav:OnOpen()
    cB_Bags.main:Show()
    cbNeav:ShowBags(cB_Bags.armor, cB_Bags.bagNew, cB_Bags.bagItemSets, cB_Bags.gem, cB_Bags.quest, cB_Bags.consumables, cB_Bags.battlepet, cB_Bags.tradegoods, cB_Bags.bagStuff, cB_Bags.bagJunk, cB_Bags.bagFishing)

    for i=1 , #cB_CustomBags do
        local bag = cB_CustomBags[i]
        if ( bag.active ) then
            cbNeav:ShowBags(cB_Bags[bag.name])
        end
    end
end

function cbNeav:OnClose()
    cbNeav:HideBags(cB_Bags.main, cB_Bags.armor, cB_Bags.bagNew, cB_Bags.bagItemSets, cB_Bags.gem, cB_Bags.quest, cB_Bags.consumables, cB_Bags.battlepet, cB_Bags.tradegoods, cB_Bags.bagStuff, cB_Bags.bagJunk, cB_Bags.bagFishing)

    for i=1 , #cB_CustomBags do
        local bag = cB_CustomBags[i]
        if ( bag.active ) then
            cbNeav:HideBags(cB_Bags[bag.name])
        end
    end
end

function cbNeav:OnBankOpened()
    cbNeav:UpdateBags()
    cB_Bags.bank:Show()
    cbNeav:ShowBags(cB_Bags.bankSets, cB_Bags.bankReagent, cB_Bags.bankArmor, cB_Bags.bankGem, cB_Bags.bankQuest, cB_Bags.bankTrade, cB_Bags.bankConsumables, cB_Bags.bankBattlePet, cB_Bags.bankFishing)

    if ( cBneav.BankCustomBags ) then
        for i=1 , #cB_CustomBags do
            local bag = cB_CustomBags[i]
            if ( bag.active ) then
                cbNeav:ShowBags(cB_Bags["Bank"..bag.name])
            end
        end
    end
end

function cbNeav:OnBankClosed()
    cbNeav:HideBags(cB_Bags.bank, cB_Bags.bankSets, cB_Bags.bankReagent, cB_Bags.bankArmor, cB_Bags.bankGem, cB_Bags.bankQuest, cB_Bags.bankTrade, cB_Bags.bankConsumables, cB_Bags.bankBattlePet, cB_Bags.bankFishing)

    if ( cBneav.BankCustomBags ) then
        for i=1 , #cB_CustomBags do
            local bag = cB_CustomBags[i]
            if ( bag.active ) then
                cbNeav:HideBags(cB_Bags["Bank"..bag.name])
            end
        end
    end
end

function cbNeav:ToggleBagPosButtons()
    for i=1, #cB_CustomBags do
        local customBag = cB_CustomBags[i]
        if ( customBag and customBag.active ) then
            local bag = cB_Bags[customBag.name]

            if ( cBneav.BagPos ) then
                bag.RightButton:Hide()
                bag.LeftButton:Hide()
                bag.DownButton:Hide()
                bag.UpButton:Hide()
            else
                bag.RightButton:Show()
                bag.LeftButton:Show()
                bag.DownButton:Show()
                bag.UpButton:Show()
            end
        end
    end

    cBneav.BagPos = not cBneav.BagPos
end

local DropDownInitialized
function cbNeav:CatDropDownInit()
    if ( DropDownInitialized ) then
        return
    end

    DropDownInitialized = true
    local info = {}

    local function AddInfoItem(text)
        local caption = "cBneav_"..text
        local title = L.bagCaptions[caption] or L[text]
        info.text = title and title or text
        info.value = text

        if ( text == "-------------" or text == CANCEL ) then
            info.func = nil
        else
            info.func = function(self)
                cbNeav:CatDropDownOnClick(self, text)
            end
        end

        cbNeavCatDropDown:AddButton(info.text, text, info.func)
    end

    AddInfoItem("MarkAsNew")
    AddInfoItem("MarkAsKnown")
    AddInfoItem("-------------")
    AddInfoItem("Armor")
    AddInfoItem("BattlePet")
    AddInfoItem("Consumables")
    AddInfoItem("Quest")
    AddInfoItem("TradeGoods")
    AddInfoItem("Gem")
    AddInfoItem("Stuff")
    AddInfoItem("Fishing")
    AddInfoItem("Junk")
    AddInfoItem("Bag")

    for i=1, #cB_CustomBags do
        local bag = cB_CustomBags[i]
        if ( bag.active ) then
            AddInfoItem(bag.name)
        end
    end

    AddInfoItem("-------------")
    AddInfoItem(CANCEL)

    hooksecurefunc(NeavcBneav_Bag, "Hide", function()
        cbNeavCatDropDown:Hide()
    end)
end

function cbNeav:CatDropDownOnClick(self, type)
    local value = self.value
    local itemID = cbNeavCatDropDown.itemID

    if ( type == "MarkAsNew" ) then
        cB_KnownItems[itemID] = nil
    elseif ( type == "MarkAsKnown" ) then
        cB_KnownItems[itemID] = GetItemCount(itemID)
    else
        cBneav_CatInfo[itemID] = value
        if ( itemID ~= nil ) then
            cB_ItemClass[itemID] = nil
        end
    end
    cbNeav:UpdateBags()
end

local function StatusMsg(str1, str2, data, name, short)
    local intro = name and "|cFFFFFF00cargBags_Neav:|r " or ""
    local message = ""

    if ( data ~= nil )  then
        local on = short and "on|r" or "enabled|r"
        local off = short and "off|r" or "disabled|r"
        message = data and GREEN_FONT_COLOR:WrapTextInColorCode(on) or RED_FONT_COLOR:WrapTextInColorCode(off)
    end

    message = string.format("%s%s%s%s", intro, str1, message, str2)
    ChatFrame1:AddMessage(message)
end

local function StatusMsgVal(str1, str2, data, name)
    local intro = name and "|cFFFFFF00cargBags_Neav:|r " or ""
    local message = ""

    if ( data ~= nil ) then
        message = GREEN_FONT_COLOR:WrapTextInColorCode(data)
    end

    message = string.format("%s%s%s%s", intro, str1, message, str2)
    ChatFrame1:AddMessage(message)
end

local function HandleSlash(str)
    local str, str2 = strsplit(" ", str, 2)
    local updateBags
    local bagExists

    if ( (str == "addbag") or (str == "delbag") or (str == "movebag") or (str == "bagprio") or (str == "orderup") or (str == "orderdn")) and (not str2) then
        StatusMsg("You have to specify a name, e.g. /cbneav "..str.." TestBag.", "", nil, true, false)
        return false
    end

    local numBags, index = 0, -1
    for i,v in ipairs(cB_CustomBags) do
        numBags = numBags + 1
        if v.name == str2 then index = i end
    end

    if ((str == "delbag") or (str == "movebag") or (str == "bagprio") or (str == "orderup") or (str == "orderdn")) and (index == -1) then
        StatusMsg("There is no custom container named |cFF00FF00"..str2, "|r.", nil, true, false)
        return false
    end

    if ( str == "new" ) then
        cBneavCfg.NewItems = not cBneavCfg.NewItems
        StatusMsg("The \"New Items\" filter is now ", ".", cBneavCfg.NewItems, true, false)
        updateBags = true
    elseif ( str == "trade" ) then
        cBneavCfg.TradeGoods = not cBneavCfg.TradeGoods
        cB_filterEnabled["TradeGoods"] = cBneavCfg.TradeGoods
        StatusMsg("The \"Trade Goods\" filter is now ", ".", cBneavCfg.TradeGoods, true, false)
        updateBags = true
    elseif ( str == "armor" ) then
        cBneavCfg.Armor = not cBneavCfg.Armor
        cB_filterEnabled["Armor"] = cBneavCfg.Armor
        StatusMsg("The \"Armor and Weapons\" filter is now ", ".", cBneavCfg.Armor, true, false)
    elseif ( str == "gem" ) then
        cBneavCfg.Gem = not cBneavCfg.Gem
        cB_filterEnabled["Gem"] = cBneavCfg.Gem
        StatusMsg("The \"Gem\" filter is now ", ".", cBneavCfg.Gem, true, false)
        updateBags = true
    elseif ( str == "junk" ) then
        cBneavCfg.Junk = not cBneavCfg.Junk
        cB_filterEnabled["Junk"] = cBneavCfg.Junk
        StatusMsg("The \"Junk\" filter is now ", ".", cBneavCfg.Junk, true, false)
        updateBags = true
    elseif ( str == "sets" ) then
        cBneavCfg.ItemSets = not cBneavCfg.ItemSets
        cB_filterEnabled["ItemSets"] = cBneavCfg.ItemSets
        StatusMsg("The \"ItemSets\" filters are now ", ".", cBneavCfg.ItemSets, true, false)
        updateBags = true
    elseif ( str == "consumables" ) then
        cBneavCfg.Consumables = not cBneavCfg.Consumables
        cB_filterEnabled["Consumables"] = cBneavCfg.Consumables
        StatusMsg("The \"Consumables\" filters are now ", ".", cBneavCfg.Consumables, true, false)
        updateBags = true
    elseif ( str == "quest" ) then
        cBneavCfg.Quest = not cBneavCfg.Quest
        cB_filterEnabled["Quest"] = cBneavCfg.Quest
        StatusMsg("The \"Quest\" filters are now ", ".", cBneavCfg.Quest, true, false)
        updateBags = true
    elseif ( str == "fishing" ) then
        cBneavCfg.Fishing = not cBneavCfg.Fishing
        cB_filterEnabled["Fishing"] = cBneavCfg.Fishing
        StatusMsg("The \"Fishing\" filters are now ", ".", cBneavCfg.Fishing, true, false)
        updateBags = true
    elseif ( str == "bankfilter" ) then
        cBneavCfg.FilterBank = not cBneavCfg.FilterBank
        StatusMsg("Bank filtering is now ", ". Reload your UI for this change to take effect!", cBneavCfg.FilterBank, true, false)
    elseif ( str == "empty" ) then
        cBneavCfg.CompressEmpty = not cBneavCfg.CompressEmpty
        if ( cBneavCfg.CompressEmpty ) then
            cB_Bags.bank.DropTarget:Show()
            cB_Bags.main.DropTarget:Show()
            cB_Bags.main.EmptySlotCounter:Show()
            cB_Bags.bank.EmptySlotCounter:Show()
        else
            cB_Bags.bank.DropTarget:Hide()
            cB_Bags.main.DropTarget:Hide()
            cB_Bags.main.EmptySlotCounter:Hide()
            cB_Bags.bank.EmptySlotCounter:Hide()
        end
        StatusMsg("Empty bagspace compression is now ", ".", cBneavCfg.CompressEmpty, true, false)
        updateBags = true
    elseif ( str == "unlock" ) then
        cBneavCfg.Unlocked = not cBneavCfg.Unlocked
        StatusMsg("Movable bags are now ", ". Hold shift+alt to move.", cBneavCfg.Unlocked, true, false)
        updateBags = true
    elseif ( str == "sortbags" ) then
        cBneavCfg.SortBags = not cBneavCfg.SortBags
        StatusMsg("Auto sorting bags is now ", ". Reload your UI for this change to take effect!", cBneavCfg.SortBags, true, false)
    elseif ( str == "sortbank" ) then
        cBneavCfg.SortBank = not cBneavCfg.SortBank
        StatusMsg("Auto sorting bank is now ", ". Reload your UI for this change to take effect!", cBneavCfg.SortBank, true, false)
    elseif ( str == "scale" ) then
        local scale = tonumber(str2)
        if ( scale ) then
            cBneavCfg.scale = scale

            for _, bag in pairs(cB_Bags) do
                bag:SetScale(cBneavCfg.scale)
            end

            StatusMsgVal("Overall scale has been set to ", ".", cBneavCfg.scale, true)
        else
            StatusMsg("You have to specify a value, e.g. /cbneav scale 0.8.", "", nil, true, false)
        end
    elseif ( str == "addbag" ) then
        for i=1, #cB_CustomBags do
            local bag = cB_CustomBags[i]
            if ( bag.name == str2 ) then
                bagExists = true
            end
        end
        if ( not bagExists ) then
            local i = numBags + 1
            cB_CustomBags[i] = { name = str2, col = 0, prio = 1, active = false }
            StatusMsg("The new custom container has been created. Reload your UI for this change to take effect!", "", nil, true, false)
        else
            StatusMsg("A custom container with this name already exists.", "", nil, true, false)
        end
    elseif ( str == "delbag" ) then
        table.remove(cB_CustomBags, index)
        for key, value in pairs(cBneav_CatInfo) do
            if ( value == str2 ) then
                cBneav_CatInfo[key] = nil
            end
        end
        StatusMsg("The specified custom container has been removed. Reload your UI for this change to take effect!", "", nil, true, false)
    elseif ( str == "listbags" ) then
        if ( numBags == 0 ) then
            StatusMsgVal("There are ", " custom containers.", 0, true, false)
        else
            StatusMsgVal("There are ", " custom containers:", numBags, true, false)

            for i=1, #cB_CustomBags do
                local bag = cB_CustomBags[i]
                local location = bag.col == 0 and "right" or "left"
                local priority = bag.prio == 1 and "high" or "low"

                location = GREEN_FONT_COLOR:WrapTextInColorCode(location)
                priority = GREEN_FONT_COLOR:WrapTextInColorCode(priority)

                local message = string.format("%d. %s (%s column, %s priority)", i, bag.name, location, priority)

                StatusMsg(message, "", nil, true, false)
            end
        end
    elseif ( str == "bagpos" ) then
        cbNeav:ToggleBagPosButtons()
        StatusMsg("Custom container movers are now ", ".", cBneav.BagPos, true, false)
    elseif ( str == "bagprio" ) then
        local priority = (cB_CustomBags[index].prio + 1) % 2
        cB_CustomBags[index].prio = priority
        StatusMsg("The priority of the specified custom container has been set to |cFF00FF00"..((priority == 1) and "high" or "low").."|r. Reload your UI for this change to take effect!", "", nil, true, false)
    elseif ( str == "bankbags" ) then
        cBneavCfg.BankCustomBags = not cBneavCfg.BankCustomBags
        StatusMsg("Display of custom containers in the bank is now ", ". Reload your UI for this change to take effect!", cBneavCfg.BankCustomBags, true, false)
    else
        ChatFrame1:AddMessage("|cFFFFFF00cargBags_Neav:|r")
        StatusMsg("(", ") |cFFFFFF00unlock|r - Toggle unlocked status. Hold shift+alt to move.", cBneavCfg.Unlocked, false, true)
        StatusMsg("(", ") |cFFFFFF00new|r - Toggle the \"New Items\" filter.", cBneavCfg.NewItems, false, true)
        StatusMsg("(", ") |cFFFFFF00trade|r - Toggle the \"Trade Goods\" filter .", cBneavCfg.TradeGoods, false, true)
        StatusMsg("(", ") |cFFFFFF00armor|r - Toggle the \"Armor and Weapons\" filter .", cBneavCfg.Armor, false, true)
        StatusMsg("(", ") |cFFFFFF00gem|r - Toggle the \"Gem\" filter .", cBneavCfg.Gem, false, true)
        StatusMsg("(", ") |cFFFFFF00junk|r - Toggle the \"Junk\" filter.", cBneavCfg.Junk, false, true)
        StatusMsg("(", ") |cFFFFFF00sets|r - Toggle the \"ItemSets\" filters.", cBneavCfg.ItemSets, false, true)
        StatusMsg("(", ") |cFFFFFF00consumables|r - Toggle the \"Consumables\" filters.", cBneavCfg.Consumables, false, true)
        StatusMsg("(", ") |cFFFFFF00quest|r - Toggle the \"Quest\" filters.", cBneavCfg.Quest, false, true)
        StatusMsg("(", ") |cFFFFFF00fishing|r - Toggle the \"Fishing\" filters.", cBneavCfg.Fishing, false, true)
        StatusMsg("(", ") |cFFFFFF00bankfilter|r - Toggle bank filtering.", cBneavCfg.FilterBank, false, true)
        StatusMsg("(", ") |cFFFFFF00empty|r - Toggle empty bagspace compression.", cBneavCfg.CompressEmpty, false, true)
        StatusMsg("(", ") |cFFFFFF00sortbags|r - Toggle auto sorting the bags.", cBneavCfg.SortBags, false, true)
        StatusMsg("(", ") |cFFFFFF00sortbank|r - Toggle auto sorting the bank.", cBneavCfg.SortBank, false, true)
        StatusMsgVal("(", ") |cFFFFFF00scale|r [number] - Set the overall scale.", cBneavCfg.scale, false)
        StatusMsg("", " |cFFFFFF00addbag|r [name] - Add a custom container.")
        StatusMsg("", " |cFFFFFF00delbag|r [name] - Remove a custom container.")
        StatusMsg("", " |cFFFFFF00listbags|r - List all custom containers.")
        StatusMsg("", " |cFFFFFF00bagpos|r - Toggle buttons to move custom containers (up, down, left, right).")
        StatusMsg("(", ") |cFFFFFF00bankbags|r - Show custom containers in the bank too.", cBneavCfg.BankCustomBags, false, true)
    end

    if ( updateBags ) then
        cbNeav:UpdateBags()
    end
end

SLASH_CBNEAV1 = "/cbneav"
SlashCmdList.CBNEAV = HandleSlash

local eventWatcher = CreateFrame("Frame")
eventWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
eventWatcher:SetScript("OnEvent", function(self, event, ...)
    if ( IsReagentBankUnlocked() ) then
        NeavcBneav_Bank.reagentBtn:Show()
    else
        NeavcBneav_Bank.reagentBtn:Hide()

        local buyReagent = CreateFrame("Button", "$parentBuyReagentTab", NeavcBneav_BankReagent, "UIPanelButtonTemplate")
        buyReagent:SetText(BANKSLOTPURCHASE)
        buyReagent:SetWidth(buyReagent:GetTextWidth() + 20)
        buyReagent:SetPoint("CENTER", NeavcBneav_BankReagent, 0, 0)
        buyReagent:RegisterEvent("REAGENTBANK_PURCHASED")

        buyReagent:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(REAGENT_BANK_HELP, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        buyReagent:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        buyReagent:SetScript("OnClick", function()
            StaticPopup_Show("CONFIRM_BUY_REAGENTBANK_TAB")
        end)

        buyReagent:SetScript("OnEvent", function(event, ...)
            buyReagent:UnregisterEvent("REAGENTBANK_PURCHASED")
            NeavcBneav_Bank.reagentBtn:Show()
            buyReagent:Hide()
        end)
    end

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)

function cargBags_Neav:ResetItemClass()
    for key, value in pairs(cB_ItemClass) do
        if ( value == "NoClass" ) then
            cB_ItemClass[key] = nil
        end
    end
    cbNeav:UpdateBags()
end
