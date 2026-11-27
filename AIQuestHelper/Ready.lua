local _, ns = ...

local ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local ROW_H, WIDTH, MAX_ROWS = 34, 560, 20
local ZONE_X, ZONE_W, XP_W = 330, 150, 60
local frame

local function setWaypoint(e)
	if not (e.map and e.x and e.y and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(e.map, e.x / 100, e.y / 100))
	if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	if ok then print("|cff33ff99AI Quest Helper:|r waypoint set for " .. e.title) end
end

local function openMap(e)
	if not (e.map and WorldMapFrame) then return end
	if not WorldMapFrame:IsShown() then
		if ToggleWorldMap then pcall(ToggleWorldMap) else pcall(ShowUIPanel, WorldMapFrame) end
	end
	if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, e.map) end
end

local function zoneOf(e)
	if e.zone then return e.zone end
	local info = e.map and C_Map and C_Map.GetMapInfo and ns.call(C_Map.GetMapInfo, e.map)
	return type(info) == "table" and info.name or nil
end

local function whoText(e)
	if not e.who then return "|cff888888Turn-in not known|r" end
	if e.x and e.y and not e.text then return e.who .. string.format(" (%.1f, %.1f)", e.x, e.y) end
	return e.who
end

local function whereText(e)
	if not e.who then return "|cff888888Turn-in not known|r" end
	if e.text then return e.who end
	local t = e.who
	if e.zone then t = t .. ", " .. e.zone end
	if e.x and e.y then t = t .. string.format(" (%.1f, %.1f)", e.x, e.y) end
	return t
end

local function build()
	local f = CreateFrame("Frame", "AIQuestHelperReady", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(WIDTH, 80)
	f:SetPoint("CENTER", 0, 120)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		f:SetBackdropColor(0.06, 0.06, 0.08, 0.95)
		f:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	end
	tinsert(UISpecialFrames, "AIQuestHelperReady")

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 14, -12)

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function() f:Hide() end)

	local function head(text, x, w, justify)
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		h:SetPoint("TOPLEFT", 10 + x, -34)
		h:SetWidth(w)
		h:SetJustifyH(justify)
		h:SetText(text)
		return h
	end
	f.heads = { head("Quest", 22, 280, "LEFT"), head("Zone", ZONE_X, ZONE_W, "LEFT"), head("XP", WIDTH - 20 - XP_W - 4, XP_W, "RIGHT") }

	f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.empty:SetPoint("TOPLEFT", 14, -40)
	f.empty:SetText("No quests are ready to turn in.")

	f.rows = {}
	for i = 1, MAX_ROWS do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(WIDTH - 20, ROW_H)
		r:SetPoint("TOPLEFT", 10, -50 - (i - 1) * ROW_H)
		local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(16, 16)
		r.icon:SetPoint("TOPLEFT", 2, -3)
		r.icon:SetTexture(ICON)
		r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		r.name:SetPoint("TOPLEFT", 22, -3)
		r.name:SetWidth(ZONE_X - 30)
		r.name:SetWordWrap(false)
		r.name:SetJustifyH("LEFT")
		r.where = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.where:SetPoint("TOPLEFT", 22, -19)
		r.where:SetWidth(ZONE_X - 30)
		r.where:SetJustifyH("LEFT")
		r.where:SetWordWrap(false)
		r.zone = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.zone:SetPoint("TOPLEFT", ZONE_X, -4)
		r.zone:SetWidth(ZONE_W)
		r.zone:SetJustifyH("LEFT")
		r.zone:SetWordWrap(false)
		r.xp = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r.xp:SetPoint("TOPRIGHT", -4, -4)
		r.xp:SetWidth(XP_W)
		r.xp:SetJustifyH("RIGHT")
		r:SetScript("OnClick", function(self)
			if not self.data then return end
			setWaypoint(self.data)
			openMap(self.data)
		end)
		r:SetScript("OnEnter", function(self)
			if not self.data then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.data.title)
			GameTooltip:AddLine(whereText(self.data), 1, 1, 1, true)
			if self.data.map then GameTooltip:AddLine("Click: open the map with a waypoint", 0.6, 0.8, 1) end
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.rows[i] = r
	end

	f:SetScript("OnEvent", function(self) if self:IsShown() then self:Refresh() end end)
	f:SetScript("OnShow", function(self)
		self:RegisterEvent("QUEST_LOG_UPDATE")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:Refresh()
	end)
	f:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)

	function f:Refresh()
		local list = ns.readyQuests and ns.readyQuests() or {}
		self.title:SetText("Ready to turn in (" .. #list .. ")")
		self.empty:SetShown(#list == 0)
		for _, h in ipairs(self.heads) do h:SetShown(#list > 0) end
		local shown = math.min(#list, MAX_ROWS)
		for i, r in ipairs(self.rows) do
			local e = list[i]
			r.data = e
			if e then
				r.name:SetText(string.format("[%s] %s", e.level or "?", e.title))
				r.where:SetText((e.here and "|cff33ff99Here:|r " or "") .. whoText(e))
				r.zone:SetText(zoneOf(e) or "|cff888888-|r")
				r.xp:SetText(e.xp and e.xp > 0 and BreakUpLargeNumbers and BreakUpLargeNumbers(e.xp) or e.xp and e.xp > 0 and tostring(e.xp) or "|cff888888-|r")
				r:Show()
			else
				r:Hide()
			end
		end
		self:SetHeight(shown > 0 and (60 + shown * ROW_H) or 70)
	end
	f:Hide()
	return f
end

function ns.toggleReady()
	frame = frame or build()
	frame:SetShown(not frame:IsShown())
end

function ns.attachReadyButton(copyIcon)
	if not copyIcon or ns.readyButton then return end
	local b = CreateFrame("Button", nil, copyIcon:GetParent())
	b:SetSize(20, 20)
	b:SetFrameLevel(copyIcon:GetFrameLevel())
	b:SetPoint("RIGHT", copyIcon, "LEFT", -2, 0)
	b:SetNormalTexture(ICON)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetScript("OnClick", function() ns.toggleReady() end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Quests ready to turn in")
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	copyIcon:HookScript("OnShow", function() b:Show() end)
	copyIcon:HookScript("OnHide", function() b:Hide() end)
	b:SetShown(copyIcon:IsShown())
	ns.readyButton = b
end
if ns.questMapIcon then ns.attachReadyButton(ns.questMapIcon) end
