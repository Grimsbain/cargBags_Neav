--[[
LICENSE
    cargBags: An inventory framework addon for World of Warcraft

    Copyright (C) 2010  Constantin "Cargor" Schomburg <xconstruct@gmail.com>

    cargBags is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    cargBags is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with cargBags; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

DESCRIPTION
    Provides a Scaffold that generates a default Blizz" ContainerButton

DEPENDENCIES
    mixins/api-common.lua
]]
local addon, ns = ...
local cargBags = ns.cargBags
local mediaPath = [[Interface\AddOns\cargBags_Neav\media\]]

local modf = math.modf
local CreateColor = CreateColor

local gradientColor = {
    [0] = CreateColor(1, 0, 0, 1),
    [1] = CreateColor(1, 1, 0, 1),
    [2] = CreateColor(0, 1, 0, 1)
}

local function ItemColorGradient(perc, colors)
    if ( not colors ) then
        colors = gradientColor
    end

    local num = #colors

    if ( perc >= 1 ) then
        return colors[num]
    elseif ( perc <= 0 ) then
        return colors[0]
    end

    local segment, relperc = modf(perc*num)

    local r1, g1, b1, r2, g2, b2
    r1, g1, b1 = colors[segment]:GetRGB()
    r2, g2, b2 = colors[segment+1]:GetRGB()

    if ( not r2 or not g2 or not b2 ) then
        return colors[0]
    else
        local r = r1 + (r2-r1)*relperc
        local g = g1 + (g2-g1)*relperc
        local b = b1 + (b2-b1)*relperc

        return CreateColor(r, g, b, 1)
    end
end

local function CreateInfoString(button, position)
    local fontString = button:CreateFontString(nil, "ARTWORK")

    if ( position == "TOP" ) then
        fontString:SetJustifyH("LEFT")
        fontString:SetPoint("TOPLEFT", button, "TOPLEFT", 1.5, -1.5)
    else
        fontString:SetJustifyH("RIGHT")
        fontString:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1.5, 1.5)
    end

    fontString:SetFont(unpack(ns.options.fonts.itemCount))

    return fontString
end

local function ItemButton_Scaffold(self)
    self:SetSize(34, 34)

    local name = self:GetName()
    self.Icon = _G[name.."IconTexture"]
    self.Count = _G[name.."Count"]
    self.Cooldown = _G[name.."Cooldown"]
    self.Quest = _G[name.."IconQuestTexture"]
    self.Border = _G[name.."NormalTexture"]
    self.BorderSet = false
    self.upgradeArrow = _G[name].UpgradeIcon
    self.flashAnim = _G[name].flashAnim
    self.newItemAnim = _G[name].newitemglowAnim

    self.Cooldown:ClearAllPoints()
    self.Cooldown:SetPoint("TOPRIGHT", self.Icon, -3, -3.5)
    self.Cooldown:SetPoint("BOTTOMLEFT", self.Icon, 3, 3)
    self.Cooldown:SetHideCountdownNumbers(false)

    self.TopString = CreateInfoString(self, "TOP")
    self.BottomString = CreateInfoString(self, "BOTTOM")
end

--[[!
    Update the button with new item-information
    @param item <table> The itemTable holding information, see Implementation:GetItemInfo()
    @callback OnUpdate(item)
]]

local function ItemButton_Update(self, item)

        -- Border

    if ( not self.BorderSet ) then
        self.Border:SetTexture(mediaPath.."textureNormalWhite")
        self.Border:SetPoint("TOPRIGHT", self.Icon, "TOPRIGHT", 1, 1)
        self.Border:SetPoint("BOTTOMLEFT", self.Icon, "BOTTOMLEFT", -1, -1)
        self.BorderSet = true
    end

        -- New Item Glow

    if ( self.NewItemTexture ) then
        self.NewItemTexture:ClearAllPoints()
        self.NewItemTexture:SetAllPoints(self.Icon)

        local isNewItem = C_NewItems.IsNewItem(item.bagID, item.slotID)

        if ( isNewItem ) then
            local isBattlePayItem = IsBattlePayItem(item.bagID, item.slotID)

            if ( isBattlePayItem ) then
                self.NewItemTexture:Hide()
            else
                if ( item.quality and NEW_ITEM_ATLAS_BY_QUALITY[item.quality] ) then
                    self.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[item.quality])
                else
                    self.NewItemTexture:SetAtlas("bags-glow-white")
                end
                self.NewItemTexture:Show()
            end
            if ( not self.flashAnim:IsPlaying() and not self.newItemAnim:IsPlaying() ) then
                self.flashAnim:Play()
                self.newItemAnim:Play()
            end
        else
            self.NewItemTexture:Hide()
            if ( self.flashAnim:IsPlaying() or self.newItemAnim:IsPlaying() ) then
                self.flashAnim:Stop()
                self.newItemAnim:Stop()
            end
        end
    end

        -- Set Icon

    if ( item.texture ) then
        local tex = item.texture or (cBneavCfg.CompressEmpty and self.bgTex)

        if ( tex ) then
            self.Icon:SetTexture(tex)
            self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            self.Icon:SetColorTexture(1, 1, 1, 0.1)
            self.Icon:SetTexCoord(0, 1, 0, 1)
        end
    else
        if ( cBneavCfg.CompressEmpty ) then
            self.Icon:SetTexture(self.bgTex)
            self.Icon:SetTexCoord(0, 1, 0, 1)
        else
            self.Icon:SetColorTexture(1, 1, 1, 0.1)
            self.Icon:SetTexCoord(0, 1, 0, 1)
        end
    end

        -- Stack Count

    if ( item.count and item.count > 1 ) then
        self.Count:SetText(item.count >= 1e3 and "*" or item.count)
        self.Count:Show()
    else
        self.Count:Hide()
    end
    self.count = item.count

        -- Durability

    if ( item.canEquip and item.canEquip > 0 ) then
        local currentDurability, maxDurability = GetContainerItemDurability(item.bagID, item.slotID)

        if ( maxDurability and maxDurability > 0 and currentDurability < maxDurability ) then
            local percent = currentDurability / maxDurability
            local color = ItemColorGradient(percent)
            self.TopString:SetText(FormatPercentage(percent, true))
            self.TopString:SetTextColor(color:GetRGB())
        else
            self.TopString:SetText("")
        end
    else
        self.TopString:SetText("")
    end

        -- Item Level

    if ( item.canEquip and item.canEquip > 0 ) then
        local qualityColor = ITEM_QUALITY_COLORS[item.quality].color
        self.BottomString:SetText(item.level)
        self.BottomString:SetTextColor(qualityColor:GetRGB())
    else
        self.BottomString:SetText("")
    end

        -- Pawn Item Upgrade Arrow

    if ( self.upgradeArrow ) then
        if ( item.canEquip and item.canEquip > 0 and item.minLevel <= UnitLevel("player") and item.level > 0 ) then
            local isUpgrade = IsContainerItemAnUpgrade(item.bagID, item.slotID)
            if ( isUpgrade ) then
                self.upgradeArrow:ClearAllPoints()
                self.upgradeArrow:SetSize(17, 17)
                self.upgradeArrow:SetPoint("BOTTOMLEFT", self.Icon)
                self.upgradeArrow:Show()
            else
                self.upgradeArrow:Hide()
            end
        else
            self.upgradeArrow:Hide()
        end
    end

    self:UpdateCooldown(item)
    self:UpdateLock(item)
    self:UpdateQuest(item)

    if ( self.OnUpdate ) then self:OnUpdate(item) end
end

--[[!
    Updates the buttons cooldown with new item-information
    @param item <table> The itemTable holding information, see Implementation:GetItemInfo()
    @callback OnUpdateCooldown(item)
]]
local function ItemButton_UpdateCooldown(self, item)
    local start, duration, enable = GetContainerItemCooldown(item.bagID, item.slotID)
    CooldownFrame_Set(self.Cooldown, start, duration, enable)

    if ( self.OnUpdateCooldown ) then self:OnUpdateCooldown(item) end
end

--[[!
    Updates the buttons lock with new item-information
    @param item <table> The itemTable holding information, see Implementation:GetItemInfo()
    @callback OnUpdateLock(item)
]]
local function ItemButton_UpdateLock(self, item)
    local _, _, locked = GetContainerItemInfo(item.bagID, item.slotID)
    self.Icon:SetDesaturated(locked)

    if ( self.OnUpdateLock ) then self:OnUpdateLock(item) end
end

--[[!
    Updates the buttons quest texture with new item information
    @param item <table> The itemTable holding information, see Implementation:GetItemInfo()
    @callback OnUpdateQuest(item)
]]
local function ItemButton_UpdateQuest(self, item)
    local questBang

    if ( item.questID and not item.questActive ) then
        self.Border:SetVertexColor(1, 1, 0.35)
        questBang = true
    elseif ( item.questID or item.isQuestItem ) then
        self.Border:SetVertexColor(1, 1, 0.35)
        questBang = false
    elseif ( item.quality and item.quality > 1 ) then
        local qualityColor = ITEM_QUALITY_COLORS[item.quality].color
        self.Border:SetVertexColor(qualityColor:GetRGB())
    else
        self.Border:SetVertexColor(0.40, 0.40, 0.40)
    end

    if ( self.Quest ) then
        if ( questBang ) then
            self.Quest:SetTexture(mediaPath.."QuestBang")
            self.Border:SetVertexColor(1, 1, 0.35)
            self.Quest:Show()
        else
            self.Quest:Hide()
        end
    end

    if ( self.OnUpdateQuest ) then self:OnUpdateQuest(item) end
end

cargBags:RegisterScaffold("Default", function(self)
    self.glowTex = [[Interface\Buttons\UI-ActionButton-Border]] --! @property glowTex <string> The textures used for the glow
    self.glowAlpha = 0.8 --! @property glowAlpha <number> The alpha of the glow texture
    self.glowBlend = "ADD" --! @property glowBlend <string> The blendMode of the glow texture
    self.glowCoords = { 14/64, 50/64, 14/64, 50/64 } --! @property glowCoords <table> Indexed table of texCoords for the glow texture
    self.bgTex = nil --! @property bgTex <string> Texture used as a background if no item is in the slot

    self.CreateFrame = ItemButton_CreateFrame
    self.Scaffold = ItemButton_Scaffold

    self.Update = ItemButton_Update
    self.UpdateCooldown = ItemButton_UpdateCooldown
    self.UpdateLock = ItemButton_UpdateLock
    self.UpdateQuest = ItemButton_UpdateQuest

    self.OnEnter = ItemButton_OnEnter
    self.OnLeave = ItemButton_OnLeave
end)
