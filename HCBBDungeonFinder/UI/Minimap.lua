-- Minimap button: click toggles the window, drag repositions around the
-- minimap rim (angle persisted account-wide).
local _, NS = ...
local UI = NS.UI
local L = NS.L

local button

local function setPosition(angle)
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
                    80 * math.cos(rad), 80 * math.sin(rad))
end

local function onDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    NS.addon.db.global.minimap.angle = angle
    setPosition(angle)
end

function UI.CreateMinimap()
    button = CreateFrame("Button", "HCBBMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function() UI.Toggle() end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["TITLE"], 1, 1, 1)
        GameTooltip:AddLine(NS.Comm.healthy and L["CH_OK"] or L["CH_RECON"],
                            unpack(NS.Comm.healthy and UI.COLOR.green
                                   or UI.COLOR.yellow))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    setPosition(NS.addon.db.global.minimap.angle or 220)
    UI.UpdateMinimap()
end

function UI.UpdateMinimap()
    if not button then return end
    if NS.addon.db.global.minimap.hide then button:Hide() else button:Show() end
end
