local ADDON_NAME, ns = ...
local ICON = ns.ICON

local panel

local SECTIONS = {
	{ "Icons", {
		{ "iconQuestMap", "Quest map and quest log" },
		{ "iconDialog", "Quest and NPC dialog" },
		{ "iconBags", "Bags" },
		{ "iconBook", "Books and notes" },
	} },
	{ "Map", {
		{ "mapZoneLevels", "Level per zone" },
		{ "mapDungeons", "Dungeon entrances" },
		{ "mapRaids", "Raid entrances" },
		{ "mapColors", "Colour by your level" },
		{ "mapSearch", "Dungeon/raid search box" },
	} },
	{ "Export", {
		{ "exportQuestie", "Questie data (giver, turn-in, locations)" },
		{ "exportBags", "Bag contents in quest export" },
		{ "learnItems", "Learn where quest items drop and quest mobs die" },
	} },
	{ "Quest arrow", {
		{ "questArrow", "Arrow to nearest unfinished quest" },
		{ "questArrowLock", "Lock arrow position" },
		{ "questTarget", "Target button for quest mobs (left mine, right party)" },
		{ "questTargetLock", "Lock target button" },
		{ "questTargetFullHp", "Orange flash when the mob is already hurt" },
	} },
	{ "Combat", {
		{ "threatPlates", "Threat % under nameplates" },
	} },
}

local function build()
	local f = CreateFrame("Frame", "AIQuestHelperOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(300, 10)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
		f:SetBackdropColor(0.06, 0.06, 0.08, 0.94)
		f:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)
	end
	tinsert(UISpecialFrames, "AIQuestHelperOptions")

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 14, -12)
	title:SetText("AI Quest Helper")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetFrameLevel(f:GetFrameLevel() + 10)
	close:SetScript("OnClick", function() f:Hide() end)
	f:EnableKeyboard(true)
	f:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			pcall(self.SetPropagateKeyboardInput, self, false)
			self:Hide()
		else
			pcall(self.SetPropagateKeyboardInput, self, true)
		end
	end)
	pcall(f.SetPropagateKeyboardInput, f, true)
	-- Keyboard input cannot be passed on safely in combat: close the window when combat starts
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self) self:Hide() end)

	local y = -38
	f.checks = {}
	for _, section in ipairs(SECTIONS) do
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		h:SetPoint("TOPLEFT", 14, y)
		h:SetText(section[1]:upper())
		y = y - 16
		for _, item in ipairs(section[2]) do
			local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
			cb:SetSize(22, 22)
			cb:SetPoint("TOPLEFT", 10, y)
			local text = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			text:ClearAllPoints()
			text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
			text:SetFontObject("GameFontHighlightSmall")
			text:SetText(item[2])
			cb.key = item[1]
			cb:SetScript("OnClick", function(self) ns.setOpt(self.key, self:GetChecked() and true or false) end)
			f.checks[#f.checks + 1] = cb
			y = y - 22
		end
		y = y - 8
	end

	local sizeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sizeLabel:SetPoint("TOPLEFT", 16, y - 4)
	local function sizeText() sizeLabel:SetText(string.format("Map icon size: %d%%", math.floor((ns.opt("mapPinScale") or 1) * 100 + 0.5))) end
	sizeText()
	local function stepper(txt, delta, x)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(22, 18)
		b:SetPoint("TOPRIGHT", x, y)
		b:SetText(txt)
		b:SetScript("OnClick", function()
			local v = math.max(0.6, math.min(2, (ns.opt("mapPinScale") or 1) + delta))
			ns.setOpt("mapPinScale", math.floor(v * 10 + 0.5) / 10)
			sizeText()
		end)
	end
	stepper("-", -0.1, -40)
	stepper("+", 0.1, -14)
	y = y - 30

	local MARKERS = { [0] = "None", "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
	local mLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mLabel:SetPoint("TOPLEFT", 16, y - 4)
	local mIcon = f:CreateTexture(nil, "OVERLAY")
	mIcon:SetSize(16, 16)
	mIcon:SetPoint("LEFT", mLabel, "RIGHT", 6, 0)
	local function markerText()
		local m = ns.opt("questTargetMarker") or 0
		mLabel:SetText("Target marker: " .. MARKERS[m])
		if m > 0 then mIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m); mIcon:Show() else mIcon:Hide() end
	end
	markerText()
	local function mStep(txt, delta, x)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(22, 18)
		b:SetPoint("TOPRIGHT", x, y)
		b:SetText(txt)
		b:SetScript("OnClick", function()
			local m = ((ns.opt("questTargetMarker") or 0) + delta) % 9
			ns.setOpt("questTargetMarker", m)
			markerText()
		end)
	end
	mStep("<", -1, -40)
	mStep(">", 1, -14)
	f.markerText = markerText
	y = y - 30

	local function keyRow(txt, party)
		local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		l:SetPoint("TOPLEFT", 16, y - 4)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(48, 18)
		b:SetPoint("TOPRIGHT", -14, y)
		b:SetText("Set")
		b:SetScript("OnClick", function() if ns.showBindPrompt then ns.showBindPrompt(party) end end)
		y = y - 24
		return function() l:SetText(txt .. ": " .. (ns.bindText and ns.bindText(party) or "Not set")) end
	end
	local mineKey = keyRow("Key Mine", false)
	local partyKey = keyRow("Key Party", true)
	f.keyText = function() mineKey(); partyKey() end
	ns.onBindChange = function() if f:IsShown() then f.keyText() end end
	y = y - 6

	local mm = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	mm:SetSize(22, 22)
	mm:SetPoint("TOPLEFT", 10, y)
	local mmText = mm.Text or mm.text or mm:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mmText:ClearAllPoints()
	mmText:SetPoint("LEFT", mm, "RIGHT", 2, 0)
	mmText:SetFontObject("GameFontHighlightSmall")
	mmText:SetText("Minimap icon")
	mm:SetScript("OnClick", function(self)
		local d = ns.db().minimap
		d.hide = not self:GetChecked()
		local icon = LibStub and LibStub("LibDBIcon-1.0", true)
		if icon then if d.hide then icon:Hide(ADDON_NAME) else icon:Show(ADDON_NAME) end end
	end)
	f.minimapCheck = mm
	y = y - 30

	local ready = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	ready:SetSize(272, 22)
	ready:SetPoint("TOPLEFT", 14, y)
	ready:SetText("Quests ready to turn in")
	ready:SetScript("OnClick", function() ns.toggleReady() end)
	y = y - 30

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 14, y)
	hint:SetWidth(272)
	hint:SetJustifyH("LEFT")
	hint:SetText("/qc  copy what is open")
	y = y - 26

	f:SetHeight(-y)
	f:SetScript("OnShow", function(self)
		for _, cb in ipairs(self.checks) do cb:SetChecked(ns.opt(cb.key) and true or false) end
		self.minimapCheck:SetChecked(not ns.db().minimap.hide)
		sizeText()
		self.markerText()
		self.keyText()
	end)
	f:Hide()
	return f
end

function ns.toggleOptions()
	panel = panel or build()
	panel:SetShown(not panel:IsShown())
end

local menu
local function saveSnapshot() if SlashCmdList.AIQUESTHELPER then SlashCmdList.AIQUESTHELPER("save") end end
function ns.showMinimapMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle("AI Quest Helper")
			root:CreateButton("Ready to turn in", function() ns.toggleReady() end)
			root:CreateButton("Copy gear (Ctrl+C)", function() if AIQuestHelper_Gear then AIQuestHelper_Gear() end end)
			root:CreateButton("Save snapshot (reload)", saveSnapshot)
			root:CreateButton("Settings", function() ns.toggleOptions() end)
		end)
		return
	end
	if not menu then
		menu = CreateFrame("Frame", "AIQuestHelperMinimapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		menu:SetSize(170, 108)
		menu:SetFrameStrata("DIALOG")
		menu:EnableMouse(true)
		if menu.SetBackdrop then
			menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
			menu:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
			menu:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
		end
		local function item(i, text, fn)
			local b = CreateFrame("Button", nil, menu)
			b:SetSize(162, 24)
			b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 25)
			local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
			local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			t:SetPoint("LEFT", 8, 0); t:SetText(text)
			b:SetScript("OnClick", function() menu:Hide(); fn() end)
		end
		item(1, "Ready to turn in", function() ns.toggleReady() end)
		item(2, "Copy gear (Ctrl+C)", function() if AIQuestHelper_Gear then AIQuestHelper_Gear() end end)
		item(3, "Save snapshot (reload)", saveSnapshot)
		item(4, "Settings", function() ns.toggleOptions() end)
		tinsert(UISpecialFrames, "AIQuestHelperMinimapMenu")
		menu:SetScript("OnUpdate", function(self)
			if not self:IsMouseOver(20, -20, -20, 20) and not (owner and owner:IsMouseOver()) then
				self.away = (self.away or 0) + 1
				if self.away > 60 then self:Hide() end
			else
				self.away = 0
			end
		end)
	end
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", owner or UIParent, "BOTTOMLEFT", 0, 0)
	menu.away = 0
	menu:SetShown(not menu:IsShown())
end

local function setupMinimap()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not (LDB and icon) or icon:IsRegistered(ADDON_NAME) then return end
	local obj = LDB:NewDataObject(ADDON_NAME, {
		type = "launcher",
		text = "AI Quest Helper",
		icon = ICON,
		OnClick = function(_, button)
			if button == "RightButton" then
				ns.showMinimapMenu(_)
			else
				ns.toggleOptions()
			end
		end,
		OnTooltipShow = function(tt)
			tt:AddLine("AI Quest Helper")
			tt:AddLine("Left-click: settings", 1, 1, 1)
			tt:AddLine("Right-click: menu (ready to turn in, save snapshot, settings)", 1, 1, 1)
		end,
	})
	icon:Register(ADDON_NAME, obj, ns.db().minimap)
end

local function setupBlizzardPanel()
	local p = CreateFrame("Frame")
	p.name = "AI Quest Helper"
	local t = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText("AI Quest Helper")
	local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	b:SetSize(160, 24)
	b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
	b:SetText("Open settings")
	b:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
		ns.toggleOptions()
	end)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(p, "AI Quest Helper")
		Settings.RegisterAddOnCategory(cat)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(p)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	pcall(setupMinimap)
	pcall(setupBlizzardPanel)
end)
